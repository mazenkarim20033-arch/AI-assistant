import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
import UIKit

/// A tool call shown in the feed as a card: pending -> (confirm) -> running -> done / failed.
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
}

enum FeedItem: Identifiable {
    case user(id: UUID, text: String)
    case assistant(id: UUID, text: String)
    case image(id: UUID, image: UIImage)
    /// A message from the app itself (not the model), e.g. a capability that isn't connected yet.
    case notice(id: UUID, text: String)
    case action(ActionCard)

    var id: UUID {
        switch self {
        case .user(let id, _), .assistant(let id, _), .image(let id, _), .notice(let id, _): return id
        case .action(let card): return card.id
        }
    }
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
    @Published var selectedModelID = ModelOption.all[0].id

    let notes: NoteStore
    private let toolList: [any AgentTool]
    private let tools: [String: any AgentTool]
    private var container: ModelContainer?

    init() {
        let store = NoteStore()
        let all: [any AgentTool] = [
            SaveNoteTool(store: store),
            SearchNotesTool(store: store),
            ListNotesTool(store: store),
        ]
        notes = store
        toolList = all
        tools = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
    }

    private var selectedModel: ModelOption {
        ModelOption.all.first { $0.id == selectedModelID } ?? ModelOption.all[0]
    }

    var selectedModelName: String {
        // "Llama 3.2 3B (best, ~1.9 GB)" -> "Llama 3.2 3B"
        selectedModel.name.components(separatedBy: " (").first ?? selectedModel.name
    }

    /// Adds an image to the conversation. Visual analysis isn't connected yet, so say so plainly.
    func attachImage(_ image: UIImage) {
        feed.append(.image(id: UUID(), image: image))
        feed.append(.notice(
            id: UUID(),
            text: "Image added to this conversation. Visual analysis isn't connected yet, so PORTAL can't read or describe it. Text actions like notes still work."
        ))
    }

    // MARK: - Model

    func loadModel() async {
        phase = .loading(0)
        // Keep MLX's buffer cache small; iOS kills apps that use too much memory.
        Memory.cacheLimit = 20 * 1024 * 1024
        // Defined here (not inline) because the macro pastes this expression into generated code.
        let reportProgress: @Sendable (Progress) -> Void = { [weak self] progress in
            let fraction = progress.fractionCompleted
            Task { @MainActor in
                self?.phase = .loading(fraction)
            }
        }
        let configuration = selectedModel.configuration
        do {
            container = try await #huggingFaceLoadModelContainer(
                configuration: configuration,
                progressHandler: reportProgress
            )
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Back to the setup screen to pick another model. Drops the loaded model to free memory.
    func unloadModel() {
        container = nil
        isThinking = false
        phase = .idle
    }

    func clearFeed() {
        feed = []
    }

    // MARK: - Agent loop

    /// The model's whole job: turn the request into one JSON action.
    private var systemPrompt: String {
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

    func submit(_ text: String) {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let container, !request.isEmpty, !isThinking else { return }
        feed.append(.user(id: UUID(), text: request))
        isThinking = true
        Task {
            defer { isThinking = false }
            do {
                // A fresh session per request: no history, so memory stays flat and answers stay predictable.
                let session = ChatSession(
                    container,
                    instructions: systemPrompt,
                    generateParameters: GenerateParameters(maxTokens: 160, maxKVSize: 2048, temperature: 0.1)
                )
                let raw = try await session.respond(to: request)
                handle(raw)
            } catch {
                feed.append(.assistant(id: UUID(), text: "Error: \(error.localizedDescription)"))
            }
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
        Task { await run(id) }
    }

    func cancel(_ id: UUID) {
        update(id) { $0.state = .cancelled }
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

    private func update(_ id: UUID, _ change: (inout ActionCard) -> Void) {
        for index in feed.indices {
            if case .action(var card) = feed[index], card.id == id {
                change(&card)
                feed[index] = .action(card)
                return
            }
        }
    }
}
