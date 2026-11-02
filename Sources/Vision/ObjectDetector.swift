import CoreML
import UIKit
import Vision

/// Finds common objects (80 everyday types such as remote, cup, laptop, person) and where they are,
/// fully on the phone, using Apple's published YOLOv3 Core ML model. The build downloads that model
/// into the app bundle; if it's missing, `isAvailable` is false and nothing is detected.
/// Source label for results: DETECTED. Its confidences are the model's own.
final class ObjectDetector {
    struct Detection: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
        /// Normalized 0...1 with the origin at the top-left of the image.
        let rect: CGRect
    }

    static let shared = ObjectDetector()

    private let model: VNCoreMLModel?
    var isAvailable: Bool { model != nil }

    init() {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all   // lets Core ML use the Neural Engine
        if let url = Bundle.main.url(forResource: "YOLOv3Detector", withExtension: "mlmodelc"),
           let coreML = try? MLModel(contentsOf: url, configuration: configuration) {
            model = try? VNCoreMLModel(for: coreML)
        } else {
            model = nil
        }
    }

    func detect(pixelBuffer: CVPixelBuffer, minimumConfidence: Float = 0.4) throws -> [Detection] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        return try run(handler, minimumConfidence)
    }

    func detect(image: UIImage, minimumConfidence: Float = 0.4) throws -> [Detection] {
        guard let cgImage = image.upright().cgImage else { return [] }
        return try run(VNImageRequestHandler(cgImage: cgImage, options: [:]), minimumConfidence)
    }

    /// Runs on a background thread so the interface stays smooth.
    static func detect(_ image: UIImage) async -> [Detection] {
        await Task.detached(priority: .userInitiated) {
            (try? ObjectDetector.shared.detect(image: image)) ?? []
        }.value
    }

    private func run(_ handler: VNImageRequestHandler, _ minimumConfidence: Float) throws -> [Detection] {
        guard let model else { return [] }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill   // what the YOLO model was trained with
        try handler.perform([request])

        let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
        return observations.compactMap { observation in
            guard let top = observation.labels.first, top.confidence >= minimumConfidence else { return nil }
            let box = observation.boundingBox   // origin at the bottom-left
            let rect = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            return Detection(label: Self.readable(top.identifier), confidence: top.confidence, rect: rect)
        }
    }

    private static func readable(_ identifier: String) -> String {
        identifier == "tvmonitor" ? "tv" : identifier.replacingOccurrences(of: "_", with: " ")
    }
}
