import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

@MainActor
final class ChatViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading(Double)   // 0...1 download progress; 1 means loading into memory
        case ready
        case failed(String)
    }

    static let defaultSystemPrompt = "You are a helpful personal assistant running fully on the user's iPhone. Be concise."

    @Published var phase: Phase = .idle
    @Published var messages: [ChatMessage] = []
    @Published var isGenerating = false
    @Published var selectedModelID = ModelOption.all[0].id
    @Published var systemPrompt = ChatViewModel.defaultSystemPrompt

    private var session: ChatSession?
    private var generation: Task<Void, Never>?

    private var selectedModel: ModelOption {
        ModelOption.all.first { $0.id == selectedModelID } ?? ModelOption.all[0]
    }

    func loadModel() async {
        phase = .loading(0)
        // Keep MLX's buffer cache small; iOS kills apps that use too much memory.
        Memory.cacheLimit = 20 * 1024 * 1024
        do {
            let container = try await #huggingFaceLoadModelContainer(
                configuration: selectedModel.configuration,
                progressHandler: { [weak self] progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor in self?.phase = .loading(fraction) }
                }
            )
            // maxKVSize caps the conversation memory (rotating cache) so long chats can't grow unbounded.
            session = ChatSession(
                container,
                instructions: systemPrompt,
                generateParameters: GenerateParameters(maxTokens: 1024, maxKVSize: 2048, temperature: 0.7)
            )
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func send(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let session, !prompt.isEmpty, !isGenerating else { return }
        messages.append(ChatMessage(role: .user, text: prompt))
        messages.append(ChatMessage(role: .assistant, text: ""))
        let index = messages.count - 1
        isGenerating = true
        generation = Task {
            do {
                for try await chunk in session.streamResponse(to: prompt) {
                    messages[index].text += chunk
                }
            } catch is CancellationError {
                // stopped by the user
            } catch {
                messages[index].text += "\n[Error: \(error.localizedDescription)]"
            }
            if messages[index].text.isEmpty { messages[index].text = "…" }
            isGenerating = false
        }
    }

    func stop() {
        generation?.cancel()
    }

    func newChat() {
        generation?.cancel()
        messages = []
        isGenerating = false
        let session = session
        Task { await session?.clear() }
    }

    /// Back to the setup screen to pick another model. Drops the loaded model to free memory.
    func unloadModel() {
        generation?.cancel()
        session = nil
        messages = []
        isGenerating = false
        phase = .idle
    }
}
