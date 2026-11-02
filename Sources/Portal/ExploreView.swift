import SwiftUI

/// Home: the orb, a short greeting, one place to ask, and a camera shortcut.
/// Everything else (model, status) lives one tap away behind the status line.
struct ExploreView: View {
    @EnvironmentObject var vm: AgentViewModel
    @EnvironmentObject var router: PortalRouter

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.violet.opacity(0.16), .clear],
                center: .top, startRadius: 10, endRadius: 460
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("PORTAL")
                    .font(.system(size: 13, weight: .regular))
                    .tracking(9)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, Theme.Space.m)

                Spacer()

                PortalOrb(size: 240, thinking: vm.isThinking)

                VStack(spacing: Theme.Space.s) {
                    Text(greeting)
                        .font(Theme.Typeface.display)
                    statusLine
                }
                .padding(.top, Theme.Space.l)

                Spacer()

                interactionBar
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.bottom, Theme.Space.s)
            }
        }
        .foregroundStyle(.white)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        case 18..<23: return "Good evening"
        default: return "Hello"
        }
    }

    /// One quiet line. Tapping it opens the model and system details.
    private var statusLine: some View {
        Button { router.showModelSheet = true } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.phase == .ready ? Theme.cyan : Theme.tertiaryText)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var statusText: String {
        switch vm.phase {
        case .ready: return "On this iPhone · \(vm.selectedModelName)"
        case .loading(let fraction): return fraction < 1 ? "Downloading \(Int(fraction * 100))%" : "Waking up…"
        case .failed: return "Couldn't load · tap for details"
        case .idle: return "Tap to wake PORTAL"
        }
    }

    private var interactionBar: some View {
        HStack(spacing: Theme.Space.s) {
            HStack(spacing: 0) {
                Button { router.tab = .ask } label: {
                    HStack {
                        Text("Ask PORTAL…")
                            .font(Theme.Typeface.body)
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                PhotoPickerButton(onPicked: { router.present(image: $0) }) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.leading, Theme.Space.m)
            .padding(.trailing, Theme.Space.xs)
            .frame(height: 56)
            .background(Theme.panel, in: Capsule())

            Button { router.showCamera = true } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.signature))
                    .shadow(color: Theme.blue.opacity(0.4), radius: 14)
            }
            .accessibilityLabel("Open camera")
        }
    }
}
