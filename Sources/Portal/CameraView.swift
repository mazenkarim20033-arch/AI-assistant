import SwiftUI

/// Camera screen layout. The live preview and capture are not connected yet (Phase 3),
/// so the viewfinder says so and the capture button is disabled. Gallery selection works.
struct CameraView: View {
    @EnvironmentObject var router: PortalRouter

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
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.panel.opacity(0.5))
            CornerBrackets()
                .stroke(Theme.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            VStack(spacing: 10) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.secondaryText)
                Text("Live preview not connected yet")
                    .font(.subheadline.weight(.medium))
                Text("Camera capture arrives in the next phase.\nYou can choose a photo from your library now.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(24)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .padding(.horizontal, 24)
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

            ZStack {
                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 3).frame(width: 76, height: 76)
                Circle().fill(Color.white.opacity(0.25)).frame(width: 60, height: 60)
            }
            .accessibilityLabel("Capture (not available yet)")

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
