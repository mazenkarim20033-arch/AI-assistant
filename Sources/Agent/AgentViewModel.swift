import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Network
import Tokenizers
import UIKit

/// A card in the conversation: a tool action, or a question the app asks the user (e.g. a download).
/// pending -> (confirm) -> running -> done / failed.
struct ActionCard: Identifiable {
    enum State {
        case pending
        case running
        case done(String)
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let toolName: String
    let title: String
    let args: [String: String]
    var state: State
    var confirmLabel = "Confirm"
    var cancelLabel = "Cancel"
}

enum FeedItem: Identifiable {
    case user(id: UUID, text: String)
    case assistant(id: UUID, text: String)
    case image(id: UUID, image: UIImage)
    /// A message from the app itself (not the model): progress, or what a tool used.
    case notice(id: UUID, text: String)
    case action(ActionCard)

    var id: UUID {
        switch self {
        case .user(let id, _), .assistant(let id, _), .image(let id, _), .notice(let id, _): return id
        case .action(let card): return card.id
        }
    }
}

/// One turn of the conversation, kept so the language model can be reloaded (it is unloaded while
/// the vision model runs) without forgetting what was said.
struct Turn {
    let isUser: Bool
    let text: String
}

@MainActor
final class AgentViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading(Double)   // 0...1 download progress; 1 means loading into memory
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var feed: [FeedItem] = []
    @Published var isThinking = false
    /// The chosen model is remembered, and loaded automatically on the next launch.
    @Published var selectedModelID = ModelOption.defaultID {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: "selectedModelID") }
    }

    private var didAutoLoad = false
    private var loadEpoch = 0              // bumped to discard a load that finishes after being cancelled
    private var visionHold = false         // true while a vision model is using the memory
    private var restoreAfterVision = false

    /// Register tools here. With none registered the app is a plain conversation; as soon as one
    /// is added, requests go through the JSON action router below and results appear as cards.
    private static func makeTools() -> [any AgentTool] {
        []
    }

    private let toolList: [any AgentTool]
    private let tools: [String: any AgentTool]

    // Shared with the photo pipeline (AgentViewModel+Photos.swift).
    var container: ModelContainer?
    var chatSession: ChatSession?
    var generation: Task<Void, Never>?
    var vision: VisionModelService?
    var transcript: [Turn] = []
    var currentPhoto: UIImage?
    var currentOCR: String?
    var currentObjects: [ObjectDetector.Detection] = []
    var currentLabels: [ClassificationLabel] = []
    var photoContext: String?
    /// True from the moment a photo is shared until the first question about it is answered.
    /// That first question triggers one look with the vision model, aimed at what was asked.
    var photoNeedsLook = false
    private var decisions: [UUID: CheckedContinuation<Bool, Never>] = [:]

    static let chatPrompt = """
        You are PORTAL, a friendly assistant running privately on the user's iPhone. \
        Keep answers short and clear. If you are not sure, say so. \
        You cannot see images yourself. When the user shares a photo, the app gives you notes from its \
        vision tools (an object detector, text recognition and a vision model). Treat the notes as \
        evidence, not certain fact: say which parts are certain and which are guesses. \
        Only if the user asks about a specific visible part of a shared photo (a button, a label, a colour, \
        a position) that the notes do not cover, reply with exactly [LOOK: <a specific question about the \
        photo>] and nothing else; the app will look again and give you the answer. Never do this for general \
        questions you can answer from your own knowledge, never more than once per question, and never when \
        no photo was shared.
        """

    init() {
        let all = Self.makeTools()
        toolList = all
        tools = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })

        if let stored = UserDefaults.standard.string(forKey: "selectedModelID"),
           ModelOption.all.contains(where: { $0.id == stored }) {
            selectedModelID = stored
        }
    }

    private var selectedModel: ModelOption {
        ModelOption.all.first { $0.id == selectedModelID } ?? ModelOption.all[0]
    }

    var selectedModelName: String {
        // "Llama 3.2 3B (best, ~1.9 GB)" -> "Llama 3.2 3B"
        selectedModel.name.components(separatedBy: " (").first ?? selectedModel.name
    }

    // MARK: - Model

    /// Loads the chosen model once per launch. On a cellular connection it does nothing, so a
    /// first-time download can't use mobile data by surprise; the user can still load it manually.
    func autoLoad() async {
        guard phase == .idle, !didAutoLoad else { return }
        didAutoLoad = true
        let onCellular = await Self.isExpensiveNetwork()
        guard !onCellular else { return }
        await loadModel()
    }

    /// True on cellular or other metered connections. Answers once, then stops monitoring.
    private nonisolated static func isExpensiveNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let once = OneShot()
            monitor.pathUpdateHandler = { path in
                guard !once.done else { return }
                once.done = true
                monitor.cancel()
                continuation.resume(returning: path.isExpensive)
            }
            monitor.start(queue: DispatchQueue(label: "portal.network"))
        }
    }

    private final class OneShot: @unchecked Sendable {
        var done = false   // only touched on the monitor's serial queue
    }

    /// Frees the language model so a vision model can use the memory (both don't fit together on
    /// the iPhone 15). Remembers to bring the language model back with `resumeAfterVision`.
    func suspendForVision() {
        if phase == .ready { restoreAfterVision = true }
        if case .loading = phase { restoreAfterVision = true }
        visionHold = true
        loadEpoch += 1
        container = nil
        chatSession = nil
        phase = .idle
        Memory.clearCache()
    }

    func resumeAfterVision() async {
        visionHold = false
        guard restoreAfterVision else { return }
        restoreAfterVision = false
        await loadModel()
    }

    func loadModel() async {
        guard !visionHold else { return }
        loadEpoch += 1
        let epoch = loadEpoch
        phase = .loading(0)
        // Keep MLX's buffer cache small; iOS kills apps that use too much memory.
        Memory.cacheLimit = 20 * 1024 * 1024
        // Defined here (not inline) because the macro pastes this expression into generated code.
        let reportProgress: @Sendable (Progress) -> Void = { [weak self] progress in
            let fraction = progress.fractionCompleted
            Task { @MainActor in
                guard let self, self.loadEpoch == epoch else { return }
                self.phase = .loading(fraction)
            }
        }
        let configuration = selectedModel.configuration
        do {
            let loaded = try await #huggingFaceLoadModelContainer(
                configuration: configuration,
                progressHandler: reportProgress
            )
            guard epoch == loadEpoch else { return }   // cancelled while loading (e.g. vision took over)
            container = loaded
            chatSession = makeChatSession(loaded)
            phase = .ready
        } catch {
            guard epoch == loadEpoch else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    /// Back to the setup screen to pick another model. Drops the loaded model to free memory.
    func unloadModel() {
        generation?.cancel()
        container = nil
        chatSession = nil
        isThinking = false
        phase = .idle
    }

    /// A new session starts from the saved notes and recent conversation, so reloading the model
    /// (after the vision model ran) doesn't make it forget. maxKVSize keeps memory bounded.
    private func makeChatSession(_ container: ModelContainer) -> ChatSession {
        var instructions = Self.chatPrompt
        if let photoContext {
            instructions += "\n\nNotes from the photo the user shared:\n\(photoContext)"
        }
        let recent = transcript.suffix(6)
        if !recent.isEmpty {
            let lines = recent.map { ($0.isUser ? "User: " : "PORTAL: ") + String($0.text.prefix(400)) }
            instructions += "\n\nConversation so far:\n" + lines.joined(separator: "\n")
        }
        return ChatSession(
            container,
            instructions: instructions,
            generateParameters: GenerateParameters(maxTokens: 512, maxKVSize: 2048, temperature: 0.6)
        )
    }

    func newConversation() {
        generation?.cancel()
        resolveDecisions(false)
        feed = []
        transcript = []
        currentPhoto = nil
        currentOCR = nil
        currentObjects = []
        currentLabels = []
        photoContext = nil
        photoNeedsLook = false
        isThinking = false
        if let container {
            chatSession = makeChatSession(container)
        }
    }

    func stopGenerating() {
        generation?.cancel()
        resolveDecisions(false)
    }

    // MARK: - Requests

    func submit(_ text: String) {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard container != nil, !request.isEmpty, !isThinking else { return }
        feed.append(.user(id: UUID(), text: request))
        transcript.append(Turn(isUser: true, text: request))
        isThinking = true
        // Nothing here may hold on to the language model (container or session) while a request runs:
        // the vision model needs that memory, and a leftover reference would keep both loaded and crash.
        generation = Task {
            defer { self.isThinking = false }
            if self.photoNeedsLook {
                await self.answerAboutPhoto(request)
            } else if self.toolList.isEmpty {
                await self.streamReply(to: request)
            } else {
                await self.routeToTool(request)
            }
        }
    }

    /// Plain conversation: the reply streams into one bubble as it is generated. If the model asks
    /// to look at the photo again ("[LOOK: ...]"), the app runs the vision model and the model then answers.
    func streamReply(to request: String, allowLook: Bool = true) async {
        let id = UUID()
        feed.append(.assistant(id: id, text: ""))
        let reply = await generate(request, into: id, allowLook: allowLook)   // the session is released here

        if allowLook, currentPhoto != nil, let question = Self.lookQuestion(in: reply) {
            feed.removeAll { $0.id == id }
            await lookAgain(question: question)
            return
        }
        if !reply.isEmpty {
            transcript.append(Turn(isUser: false, text: reply))
        }
    }

    /// Streams one reply into the bubble `id`. Kept separate so the chat session only lives inside
    /// this call and is released before any model swap.
    private func generate(_ request: String, into id: UUID, allowLook: Bool) async -> String {
        guard let session = chatSession else {
            setAssistantText(id, "The language model isn't loaded.")
            return ""
        }
        var reply = ""
        do {
            for try await chunk in session.streamResponse(to: request) {
                reply += chunk
                if allowLook, currentPhoto != nil, reply.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[LOOK") {
                    setAssistantText(id, "")   // hide the raw request
                } else {
                    setAssistantText(id, reply)
                }
            }
        } catch is CancellationError {
            // stopped by the user
        } catch {
            reply += "\n[Error: \(error.localizedDescription)]"
            setAssistantText(id, reply)
        }
        return reply
    }

    func setAssistantText(_ id: UUID, _ text: String) {
        guard let index = feed.firstIndex(where: { $0.id == id }) else { return }
        feed[index] = .assistant(id: id, text: text)
    }

    func setNotice(_ id: UUID, _ text: String) {
        guard let index = feed.firstIndex(where: { $0.id == id }) else { return }
        feed[index] = .notice(id: id, text: text)
    }

    private static func lookQuestion(in text: String) -> String? {
        guard let start = text.range(of: "[LOOK:") else { return nil }
        let rest = text[start.upperBound...]
        let end = rest.firstIndex(of: "]") ?? rest.endIndex
        let question = rest[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return question.isEmpty ? nil : question
    }

    // MARK: - Questions to the user (e.g. "download the vision model?")

    /// Shows a card with two buttons and waits for the answer.
    func askDecision(_ title: String, confirm: String, cancel: String) async -> Bool {
        let card = ActionCard(toolName: "decision", title: title, args: [:], state: .pending, confirmLabel: confirm, cancelLabel: cancel)
        feed.append(.action(card))
        return await withCheckedContinuation { continuation in
            decisions[card.id] = continuation
        }
    }

    private func resolveDecisions(_ value: Bool) {
        let pending = decisions
        decisions = [:]
        for (id, continuation) in pending {
            update(id) { $0.state = .cancelled }
            continuation.resume(returning: value)
        }
    }

    // MARK: - Tool routing (used once tools are registered)

    /// The model's whole job: turn the request into one JSON action.
    private var routerPrompt: String {
        var lines = [
            "You control a phone assistant. Turn the user's message into exactly ONE action.",
            "Answer with ONLY a single JSON object and nothing else.",
            "",
            "Tools:",
        ]
        lines += toolList.map { "- " + $0.promptLine }
        lines.append(#"- reply: only if no tool fits. args: {"text": "<short answer>"}"#)
        lines += ["", "Examples:"]
        for tool in toolList {
            for (message, json) in tool.examples {
                lines.append("User: \(message)")
                lines.append(json)
            }
        }
        lines.append("User: hello")
        lines.append(#"{"tool":"reply","args":{"text":"Hi! Tell me what to do."}}"#)
        return lines.joined(separator: "\n")
    }

    private func routeToTool(_ request: String) async {
        guard let container else { return }
        do {
            // A fresh session per request: no history, so memory stays flat and answers stay predictable.
            let session = ChatSession(
                container,
                instructions: routerPrompt,
                generateParameters: GenerateParameters(maxTokens: 160, maxKVSize: 2048, temperature: 0.1)
            )
            let raw = try await session.respond(to: request)
            handle(raw)
        } catch {
            feed.append(.assistant(id: UUID(), text: "Error: \(error.localizedDescription)"))
        }
    }

    private func handle(_ raw: String) {
        guard let call = AgentParser.parse(raw) else {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            feed.append(.assistant(id: UUID(), text: text.isEmpty ? "…" : text))
            return
        }
        if call.tool == "reply" {
            feed.append(.assistant(id: UUID(), text: call.args["text"] ?? raw))
            return
        }
        guard let tool = tools[call.tool] else {
            feed.append(.assistant(id: UUID(), text: "I don't have a tool called \(call.tool)."))
            return
        }
        let card = ActionCard(
            toolName: tool.name,
            title: tool.summary(for: call.args),
            args: call.args,
            state: .pending
        )
        feed.append(.action(card))
        if !tool.needsConfirmation {
            Task { await run(card.id) }
        }
    }

    // MARK: - Action cards

    func confirm(_ id: UUID) {
        if let continuation = decisions.removeValue(forKey: id) {
            update(id) { $0.state = .done("OK") }
            continuation.resume(returning: true)
            return
        }
        Task { await run(id) }
    }

    func cancel(_ id: UUID) {
        update(id) { $0.state = .cancelled }
        decisions.removeValue(forKey: id)?.resume(returning: false)
    }

    private func run(_ id: UUID) async {
        guard let card = findCard(id), case .pending = card.state, let tool = tools[card.toolName] else { return }
        update(id) { $0.state = .running }
        do {
            let result = try await tool.run(card.args)
            update(id) { $0.state = .done(result) }
        } catch {
            update(id) { $0.state = .failed(error.localizedDescription) }
        }
    }

    private func findCard(_ id: UUID) -> ActionCard? {
        for item in feed {
            if case .action(let card) = item, card.id == id { return card }
        }
        return nil
    }

    func update(_ id: UUID, _ change: (inout ActionCard) -> Void) {
        for index in feed.indices {
            if case .action(var card) = feed[index], card.id == id {
                change(&card)
                feed[index] = .action(card)
                return
            }
        }
    }
}
