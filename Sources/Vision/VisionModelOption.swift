import MLXLMCommon
import MLXVLM

/// Vision-language models offered for Live Look. Both are 4-bit or small MLX builds. They are
/// listed side by side so they can be compared on the phone (the answer shows its timing).
struct VisionModelOption: Identifiable {
    let id: String
    let name: String
    let size: String   // approximate download size, shown before the first download
    let configuration: ModelConfiguration

    static let defaultID = "qwen2-vl-2b"

    static let all: [VisionModelOption] = [
        VisionModelOption(
            id: "qwen2-vl-2b",
            name: "Qwen2-VL 2B (reads text well, ~1.3 GB)",
            size: "about 1.3 GB",
            configuration: VLMRegistry.qwen2VL2BInstruct4Bit
        ),
        VisionModelOption(
            id: "smolvlm2-500m",
            name: "SmolVLM2 500M (faster, simpler, ~1 GB)",
            size: "about 1 GB",
            configuration: VLMRegistry.smolvlm
        ),
    ]
}
