import UIKit

/// Runs the on-device analyzers for the image on the details sheet and holds their results.
@MainActor
final class AnalysisViewModel: ObservableObject {
    enum State {
        case idle
        case running
        case done(ImageAnalysis, [ObjectDetector.Detection])
        case failed(String)
    }

    @Published var state: State = .idle
    private var analyzedToken: UUID?

    /// `token` identifies the image; the same image is not analyzed twice.
    func analyze(_ image: UIImage?, token: UUID) async {
        guard let image, analyzedToken != token else { return }
        analyzedToken = token
        state = .running
        do {
            let result = try await AppleVisionAnalyzer.analyze(image)
            let objects = await ObjectDetector.detect(image)
            guard analyzedToken == token else { return }   // a newer image replaced this one
            state = .done(result, objects)
        } catch {
            guard analyzedToken == token else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
