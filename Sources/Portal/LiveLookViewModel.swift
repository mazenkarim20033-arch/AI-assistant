import UIKit

/// Live Look: ask about what the camera sees. The camera runs live, but each answer is based on one
/// frame captured when you ask. After the first question the frame is held, so follow-up questions
/// reason about the same image; "look again" goes back to live.
@MainActor
final class LiveLookViewModel: ObservableObject {
    enum State: Equatable {
        case live
        case thinking
        case answering
        case answered
        case failed(String)
    }

    @Published var state: State = .live
    @Published var answer = ""
    @Published var stats = ""
    /// The held frame once a question has been asked; nil while live.
    @Published var frozen: UIImage?
    @Published var needsConsent = false

    private var pendingQuestion: String?
    private var consentGiven = false
    private var hasSession = false
    private var task: Task<Void, Never>?

    var isBusy: Bool { state == .thinking || state == .answering }

    func ask(_ text: String, camera: CameraController, vision: VisionModelService, language: AgentViewModel) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isBusy else { return }

        // The first use downloads a large model: ask before using the user's data.
        if !vision.isReady, !vision.hasDownloaded, !consentGiven {
            pendingQuestion = question
            needsConsent = true
            return
        }
        task = Task { await run(question, camera: camera, vision: vision, language: language) }
    }

    func confirmDownload(camera: CameraController, vision: VisionModelService, language: AgentViewModel) {
        consentGiven = true
        needsConsent = false
        if let question = pendingQuestion {
            pendingQuestion = nil
            ask(question, camera: camera, vision: vision, language: language)
        }
    }

    func declineDownload() {
        needsConsent = false
        pendingQuestion = nil
    }

    func stop() {
        task?.cancel()
    }

    /// Back to live: forget the held frame and the conversation about it.
    func lookAgain(vision: VisionModelService) {
        task?.cancel()
        frozen = nil
        hasSession = false
        answer = ""
        stats = ""
        state = .live
        vision.resetSession()
    }

    /// Called when the camera screen closes.
    func shutdown(vision: VisionModelService, language: AgentViewModel) {
        task?.cancel()
        vision.unload()
        Task { await language.resumeAfterVision() }
    }

    private func run(_ question: String, camera: CameraController, vision: VisionModelService, language: AgentViewModel) async {
        state = .thinking
        answer = ""
        stats = ""

        if !vision.isReady {
            language.suspendForVision()
            await vision.load()
            guard !Task.isCancelled else { return }
            if case .failed(let message) = vision.phase {
                state = .failed(message)
                return
            }
        }

        var frame: UIImage?
        var ocrText: String?
        if frozen == nil || !hasSession {
            guard let captured = camera.latestFrame() else {
                state = .failed("The camera hasn't produced a frame yet. Try again in a moment.")
                return
            }
            frozen = captured
            frame = captured
            hasSession = true
            // Apple Vision's text recognition helps the model read small labels.
            ocrText = (try? await AppleVisionAnalyzer.analyze(captured))?.ocr.text
        }

        guard let stream = vision.ask(question, frame: frame, ocrText: ocrText) else {
            state = .failed("The vision model isn't loaded.")
            return
        }

        let start = Date()
        var firstWords: Double?
        do {
            for try await chunk in stream {
                if firstWords == nil {
                    firstWords = Date().timeIntervalSince(start)
                    state = .answering
                }
                answer += chunk
            }
            state = .answered
        } catch is CancellationError {
            state = .answered
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        stats = String(
            format: "%@ · first words after %.1f s, done in %.1f s",
            vision.optionName, firstWords ?? 0, Date().timeIntervalSince(start)
        )
    }
}
