import UIKit
import Vision

/// OCR and whole-image classification using Apple's Vision framework. Everything runs on the
/// phone and adds no model download. Swappable: later analyzers (e.g. a vision-language model)
/// will produce their own result types instead of widening this one.
enum AppleVisionAnalyzer {
    static func analyze(_ image: UIImage) async throws -> ImageAnalysis {
        guard let cgImage = image.upright().cgImage else { throw AnalysisError.unreadableImage }
        return try await Task.detached(priority: .userInitiated) {
            try AppleVisionAnalyzer.run(on: cgImage)
        }.value
    }

    private static func run(on cgImage: CGImage) throws -> ImageAnalysis {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // OCR
        let ocrStart = Date()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        try handler.perform([textRequest])
        let ocrSeconds = Date().timeIntervalSince(ocrStart)

        // Vision's boxes have their origin at the bottom-left, so larger midY means higher on the page.
        let observations = (textRequest.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        let lines = observations.compactMap { observation -> OCRLine? in
            guard let best = observation.topCandidates(1).first,
                  !best.string.trimmingCharacters(in: .whitespaces).isEmpty
            else { return nil }
            return OCRLine(text: best.string, confidence: best.confidence)
        }

        // Whole-image classification
        let labelStart = Date()
        let classifyRequest = VNClassifyImageRequest()
        try handler.perform([classifyRequest])
        let labelSeconds = Date().timeIntervalSince(labelStart)

        let labels = (classifyRequest.results ?? [])
            .filter { $0.confidence >= 0.12 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(6)
            .map { ClassificationLabel(name: displayName($0.identifier), confidence: $0.confidence) }

        return ImageAnalysis(
            ocr: OCRResult(lines: lines),
            labels: Array(labels),
            ocrSeconds: ocrSeconds,
            labelSeconds: labelSeconds
        )
    }

    /// "circuit_board" -> "Circuit board"
    private static func displayName(_ identifier: String) -> String {
        let spaced = identifier.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}

extension UIImage {
    /// Redraws the image so its pixels are upright (Vision reads raw pixels, not orientation metadata).
    func upright() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
