import SwiftUI

/// The camera, full screen. It shows what it can find in the live view: a box and a name around each
/// object the on-device detector recognizes. The white button takes a photo and sends it to the chat,
/// where the vision and language models work together to explain it. The detector knows 80 common
/// object types; it is detection on selected frames, not continuous understanding of the scene.
struct CameraView: View {
    @EnvironmentObject var router: PortalRouter
    @StateObject private var camera = CameraController()
    @StateObject private var detection = LiveDetectionModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            viewfinder

            VStack(spacing: 0) {
                topBar
                Spacer()
                controls
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            camera.wantsFrames = true
            camera.onCapture = { image in router.present(image: image) }
            camera.frameHandler = { [detection] buffer in detection.handle(buffer) }
            camera.start()
        }
        .onDisappear {
            camera.stop()
            detection.reset()
        }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack {
            switch camera.status {
            case .ready:
                CameraPreview(session: camera.session)
                DetectionOverlay(boxes: detection.boxes, imageSize: detection.imageSize)
            case .checking:
                ProgressView()
            case .denied:
                message(
                    icon: "camera.badge.ellipsis",
                    title: "Camera access is off",
                    detail: "Allow camera access for PORTAL in Settings. You can still choose photos from your library.",
                    showSettings: true
                )
            case .unavailable:
                message(
                    icon: "camera.metering.unknown",
                    title: "No camera available",
                    detail: "This device can't open a camera. You can still choose photos from your library.",
                    showSettings: false
                )
            }

            // A soft dark fade behind the controls so they stay readable over any scene.
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
    }

    private func message(icon: String, title: String, detail: String, showSettings: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(Theme.secondaryText)
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText)
            if showSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .padding(Theme.Space.l)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { router.showCamera = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            statusChip
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.top, Theme.Space.xs)
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(detection.isAvailable ? Theme.cyan : Color.white.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var statusText: String {
        guard detection.isAvailable else { return "Live · detector unavailable" }
        let visible = detection.boxes.filter { $0.missed == 0 }.count
        return visible == 0 ? "Live" : (visible == 1 ? "Live · 1 object" : "Live · \(visible) objects")
    }

    // MARK: Controls

    private var controls: some View {
        HStack {
            PhotoPickerButton(onPicked: { router.present(image: $0) }) {
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .light))
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            Button { camera.capture() } label: {
                ZStack {
                    Circle().strokeBorder(Color.white, lineWidth: 3).frame(width: 76, height: 76)
                    Circle().fill(Color.white).frame(width: 60, height: 60)
                        .scaleEffect(camera.isCapturing ? 0.85 : 1)
                        .animation(.easeOut(duration: 0.15), value: camera.isCapturing)
                }
            }
            .disabled(camera.status != .ready || camera.isCapturing)
            .opacity(camera.status == .ready ? 1 : 0.35)
            .accessibilityLabel("Take photo")

            Spacer()

            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.m)
    }
}
