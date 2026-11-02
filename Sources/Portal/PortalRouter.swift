import PhotosUI
import SwiftUI

/// Tab selection and which full-screen panels are open, plus the image currently being examined.
/// The image lives in memory only; nothing is written to disk.
@MainActor
final class PortalRouter: ObservableObject {
    enum Tab: Hashable {
        case explore, ask, discover, memory
    }

    @Published var tab: Tab = .explore
    @Published var showCamera = false
    @Published var showAnalysis = false
    @Published var showModelSheet = false
    @Published var currentImage: UIImage?

    /// Opens the analysis screen for a new image (closing the camera first if it is open).
    func present(image: UIImage) {
        currentImage = image
        if showCamera {
            showCamera = false
            Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                showAnalysis = true
            }
        } else {
            showAnalysis = true
        }
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
