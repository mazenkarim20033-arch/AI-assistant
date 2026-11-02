import Foundation

/// One line of text read from an image (source: OCR). `confidence` is Apple Vision's own, 0...1.
struct OCRLine: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
}

struct OCRResult {
    let lines: [OCRLine]

    var text: String { lines.map(\.text).joined(separator: "\n") }

    var averageConfidence: Float {
        lines.isEmpty ? 0 : lines.map(\.confidence).reduce(0, +) / Float(lines.count)
    }
}

/// A whole-image label from an on-device classifier (source: DETECTED). `confidence` is the classifier's own.
struct ClassificationLabel: Identifiable {
    let id = UUID()
    let name: String
    let confidence: Float
}

/// Everything the on-device analyzers found in one image, kept separate by source so the
/// interface and (later) the language model can tell OCR text from classifier labels.
struct ImageAnalysis {
    let ocr: OCRResult
    let labels: [ClassificationLabel]
    let ocrSeconds: Double
    let labelSeconds: Double

    var totalSeconds: Double { ocrSeconds + labelSeconds }
}

enum AnalysisError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "The image couldn't be read."
        }
    }
}
