import SwiftUI

/// The camera, full screen. Two things from one place:
/// - the white button takes a photo (opens the analysis screen),
/// - the ask bar asks about what the camera sees right now (Live Look).
/// The preview is live; each answer is based on one frame captured when you ask.
struct CameraView: View {
    @EnvironmentObject var router: PortalRouter
    @EnvironmentObject var vm: AgentViewModel
    @EnvironmentObject var vision: VisionModelService
    @StateObject private var camera = CameraController()
    @StateObject private var live = LiveLookViewModel()
    @State private var input = ""
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        live.ask(input, camera: camera, vision: vision, language: vm)
        input = ""
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            viewfinder

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomPanel
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            camera.wantsFrames = true
            camera.onCapture = { image in router.present(image: image) }
            camera.start()
        }
        .onDisappear {
            camera.stop()
            live.shutdown(vision: vision, language: vm)
        }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack {
            switch camera.status {
            case .ready:
                if let frozen = live.frozen {
                    Image(uiImage: frozen)
                        .resizable()
                        .scaledToFill()
                } else {
                    CameraPreview(session: camera.session)
                }
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
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 340)
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
            if live.frozen != nil {
                Button { live.lookAgain(vision: vision) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Look again")
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.top, Theme.Space.xs)
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(live.frozen == nil ? Theme.cyan : Color.white.opacity(0.6))
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var statusText: String {
        if case .loading(let fraction) = vision.phase {
            return fraction < 1 ? "Preparing vision \(Int(fraction * 100))%" : "Preparing vision…"
        }
        switch live.state {
        case .thinking: return "Looking…"
        case .answering: return "Answering…"
        case .answered, .failed: return "Held frame"
        case .live: return live.frozen == nil ? "Live" : "Held frame"
        }
    }

    // MARK: Bottom

    private var bottomPanel: some View {
        VStack(spacing: Theme.Space.s) {
            if live.needsConsent {
                consentCard
            } else if live.state != .live {
                answerCard
            }
            inputRow
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.bottom, Theme.Space.s)
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("One-time download")
                .font(Theme.Typeface.title)
            Text("To understand what the camera sees, PORTAL needs a vision model (\(vision.option.size)). It stays on this iPhone. Use Wi-Fi if you can. The language model will pause while the camera is open.")
                .font(Theme.Typeface.secondary)
                .foregroundStyle(Theme.secondaryText)
            HStack(spacing: 10) {
                Button("Not now") { live.declineDownload() }
                    .buttonStyle(GhostButtonStyle())
                Button("Download") {
                    live.confirmDownload(camera: camera, vision: vision, language: vm)
                }
                .buttonStyle(PortalButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            ProvenanceBadge(provenance: .vision)

            switch live.state {
            case .thinking:
                HStack(spacing: Theme.Space.s) {
                    ProgressView()
                    Text(vision.isReady ? "Looking at the frame…" : "Getting the vision model ready…")
                        .font(Theme.Typeface.secondary)
                        .foregroundStyle(Theme.secondaryText)
                }
            case .failed(let message):
                Text(message)
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(.red)
            default:
                ScrollView {
                    Text(live.answer)
                        .font(Theme.Typeface.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 190)
                if live.state == .answered {
                    Text("\(live.stats). Based on the frame captured when you asked; it can be wrong.")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var inputRow: some View {
        HStack(spacing: Theme.Space.s) {
            HStack(spacing: 0) {
                TextField(live.frozen == nil ? "Ask about what you see…" : "Ask a follow-up…", text: $input)
                    .font(Theme.Typeface.body)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                trailingButton
            }
            .padding(.leading, Theme.Space.m)
            .padding(.trailing, Theme.Space.xs)
            .frame(height: 56)
            .background(.ultraThinMaterial, in: Capsule())

            Button { camera.capture() } label: {
                ZStack {
                    Circle().strokeBorder(Color.white, lineWidth: 3).frame(width: 56, height: 56)
                    Circle().fill(Color.white).frame(width: 44, height: 44)
                        .scaleEffect(camera.isCapturing ? 0.85 : 1)
                        .animation(.easeOut(duration: 0.15), value: camera.isCapturing)
                }
            }
            .disabled(camera.status != .ready || camera.isCapturing)
            .opacity(camera.status == .ready ? 1 : 0.35)
            .accessibilityLabel("Take photo")
        }
    }

    /// Stop while answering, send when there is text, otherwise the photo picker.
    @ViewBuilder
    private var trailingButton: some View {
        if live.isBusy {
            Button { live.stop() } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Stop")
        } else if canSend {
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.signature)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Send")
        } else {
            PhotoPickerButton(onPicked: { router.present(image: $0) }) {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
            }
        }
    }
}
