import PhotosUI
import SwiftUI

/// Tab selection and which full-screen panels are open, plus the image shown on the details sheet.
/// Images live in memory only; nothing is written to disk.
@MainActor
final class PortalRouter: ObservableObject {
    enum Tab: Hashable {
        case home, discover
    }

    @Published var tab: Tab = .home
    @Published var showCamera = false
    @Published var showAnalysis = false
    @Published var showModelSheet = false
    @Published var currentImage: UIImage?
    /// Changes whenever a new image is set, so the details sheet knows to analyze it.
    @Published var imageToken = UUID()

    /// Set by the app root: receives every photo the user takes or picks.
    var onPhoto: ((UIImage) -> Void)?

    func setImage(_ image: UIImage) {
        currentImage = image
        imageToken = UUID()
    }

    /// Sends a photo to the chat: closes the camera, shows the chat, and starts the analysis there.
    func present(image: UIImage) {
        showCamera = false
        tab = .home
        onPhoto?(image)
    }

    /// Opens the details sheet (what each tool found) for an image in the chat.
    func showDetails(for image: UIImage) {
        setImage(image)
        showAnalysis = true
    }
}

/// A button that opens the photo library and hands back the chosen image.
/// PhotosPicker runs out of process, so no photo-library permission is needed.
struct PhotoPickerButton<Label: View>: View {
    let onPicked: (UIImage) -> Void
    let label: () -> Label
    @State private var item: PhotosPickerItem?

    init(onPicked: @escaping (UIImage) -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.onPicked = onPicked
        self.label = label
    }

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) { label() }
            .onChange(of: item) {
                guard let chosen = item else { return }
                Task {
                    if let data = try? await chosen.loadTransferable(type: Data.self),
                       let image = UIImage(data: data)?.downscaled(maxDimension: 1600) {
                        onPicked(image)
                    }
                    item = nil
                }
            }
    }
}
