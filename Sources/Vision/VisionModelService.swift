import CoreImage
import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers
import UIKit

/// Loads one vision-language model at a time and answers questions about an image.
/// Only used while the camera is open; the language model is unloaded meanwhile
/// (see `AgentViewModel.suspendForVision`) because both won't fit in memory together.
@MainActor
final class VisionModelService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading(Double)   // 0...1 download progress; 1 means loading into memory
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published var selectedID = VisionModelOption.defaultID {
        didSet { UserDefaults.standard.set(selectedID, forKey: "visionModelID") }
    }

    private var container: ModelContainer?
    private var session: ChatSession?
    private var epoch = 0   // bumped by unload, so a load that finishes late is discarded

    private static let instructions = """
        You are the eyes of a phone assistant. The user points their camera at something and asks about it. \
        Answer only from what is visible in the image and from any OCR text provided. \
        When the user mentions a colour or a position, such as "the blue button at the bottom", find that part \
        of the image and describe it. Explain what it most likely does and why you think so, and keep what you \
        can see separate from what you are guessing. If you cannot tell, say so instead of guessing. \
        Keep answers under 120 words.
        """

    init() {
        if let stored = UserDefaults.standard.string(forKey: "visionModelID"),
           VisionModelOption.all.contains(where: { $0.id == stored }) {
            selectedID = stored
        }
    }

    var option: VisionModelOption {
        VisionModelOption.all.first { $0.id == selectedID } ?? VisionModelOption.all[0]
    }

    var isReady: Bool { phase == .ready }

    var optionName: String {
        option.name.components(separatedBy: " (").first ?? option.name
    }

    private static func downloadedKey(_ id: String) -> String { "visionDownloaded.\(id)" }

    /// True once the selected model has been downloaded and loaded successfully on this phone.
    var hasDownloaded: Bool {
        UserDefaults.standard.bool(forKey: Self.downloadedKey(selectedID))
    }

    func load() async {
        guard phase != .ready else { return }
        epoch += 1
        let myEpoch = epoch
        phase = .loading(0)
        Memory.cacheLimit = 20 * 1024 * 1024
        // Defined here (not inline) because the macro pastes this expression into generated code.
        let reportProgress: @Sendable (Progress) -> Void = { [weak self] progress in
            let fraction = progress.fractionCompleted
            Task { @MainActor in
                guard let self, self.epoch == myEpoch else { return }
                self.phase = .loading(fraction)
            }
        }
        let chosen = option
        let configuration = chosen.configuration
        do {
            let loaded = try await #huggingFaceLoadModelContainer(
                configuration: configuration,
                progressHandler: reportProgress
            )
            guard epoch == myEpoch else { return }
            container = loaded
            UserDefaults.standard.set(true, forKey: Self.downloadedKey(chosen.id))
            phase = .ready
        } catch {
            guard epoch == myEpoch else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    func unload() {
        epoch += 1
        container = nil
        session = nil
        phase = .idle
    }

    /// Forgets the current image and conversation; the next question starts fresh.
    func resetSession() {
        session = nil
    }

    /// Asks about `frame`. With a frame this starts a new conversation about that image; without
    /// one it continues the current conversation (follow-up questions about the same image).
    func ask(_ question: String, frame: UIImage?, ocrText: String?) -> AsyncThrowingStream<String, Error>? {
        guard let container else { return nil }

        if let frame, let cgImage = frame.cgImage {
            let newSession = ChatSession(
                container,
                instructions: Self.instructions,
                generateParameters: GenerateParameters(maxTokens: 300, maxKVSize: 4096, temperature: 0.3),
                processing: UserInput.Processing(resize: CGSize(width: 672, height: 672))
            )
            session = newSession
            var prompt = "Question: \(question)"
            if let ocrText, !ocrText.isEmpty {
                prompt += "\n\nText read from the image by OCR (may contain mistakes):\n\(String(ocrText.prefix(600)))"
            }
            let image = UserInput.Image(source: .ciImage(CIImage(cgImage: cgImage)))
            return newSession.streamResponse(to: prompt, image: image)
        }

        guard let session else { return nil }
        return session.streamResponse(to: question)
    }
}
