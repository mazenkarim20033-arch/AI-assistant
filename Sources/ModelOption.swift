import MLXLLM
import MLXLMCommon

/// Models offered in the picker. All are 4-bit MLX builds from the mlx-community Hugging Face org.
struct ModelOption: Identifiable {
    let id: String
    let name: String
    let configuration: ModelConfiguration

    static let all: [ModelOption] = [
        ModelOption(id: "llama-3.2-1b", name: "Llama 3.2 1B (fast, ~0.7 GB)", configuration: LLMRegistry.llama3_2_1B_4bit),
        ModelOption(id: "gemma-3-1b", name: "Gemma 3 1B (~0.7 GB)", configuration: LLMRegistry.gemma3_1B_qat_4bit),
        ModelOption(id: "qwen-2.5-1.5b", name: "Qwen 2.5 1.5B (~1 GB)", configuration: LLMRegistry.qwen2_5_1_5b),
        ModelOption(id: "llama-3.2-3b", name: "Llama 3.2 3B (best, ~1.9 GB)", configuration: LLMRegistry.llama3_2_3B_4bit),
    ]
}
