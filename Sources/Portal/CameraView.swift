import SwiftUI

/// Camera screen: live preview, capture, and gallery selection.
/// Photos go to the analysis screen; analysis itself isn't connected yet.
struct CameraView: View {
    @EnvironmentObject var router: PortalRouter
    @StateObject private var camera = CameraController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                viewfinder
                Spacer()
                controls
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            camera.onCapture = { image in router.present(image: image) }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var topBar: some View {
        HStack {
            Button { router.showCamera = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            Spacer()
            SectionLabel(text: "Camera")
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var viewfinder: some View {
        ZStack {
            Theme.panel

            switch camera.status {
            case .ready:
                CameraPreview(session: camera.session)
            case .checking:
                ProgressView()
            case .denied:
                message(
                    icon: "camera.badge.ellipsis",
                    title: "Camera access is off",
                    detail: "Allow camera access for PORTAL in Settings to take photos. You can still choose photos from your library.",
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

            CornerBrackets(length: 24)
                .stroke(Theme.cyan.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .padding(14)
                .allowsHitTesting(false)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .padding(.horizontal, Theme.Space.m)
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
        .padding(24)
    }

    private var controls: some View {
        HStack {
            PhotoPickerButton(onPicked: { router.present(image: $0) }) {
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                    Text("Gallery").font(.caption)
                }
                .frame(width: 80)
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

            Button { router.showCamera = false; router.tab = .ask } label: {
                VStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 22))
                    Text("Ask").font(.caption)
                }
                .frame(width: 80)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}
