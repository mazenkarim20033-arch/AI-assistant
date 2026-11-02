import SwiftUI

/// Home screen: the orb, the camera button, and an honest status readout.
struct ExploreView: View {
    @EnvironmentObject var vm: AgentViewModel
    @EnvironmentObject var router: PortalRouter

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.violet.opacity(0.22), .clear],
                center: .top, startRadius: 20, endRadius: 420
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Text("PORTAL")
                        .font(.system(size: 20, weight: .light))
                        .tracking(12)
                        .padding(.top, 12)

                    PortalOrb(size: 210, thinking: vm.isThinking)

                    VStack(spacing: 8) {
                        Text("Point. Ask. Understand.")
                            .font(.system(size: 26, weight: .semibold))
                        Text("Your AI interface to the world around you.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: 14) {
                        Button { router.showCamera = true } label: {
                            Label("Open Camera", systemImage: "camera.viewfinder")
                        }
                        .buttonStyle(PortalButtonStyle())

                        HStack(spacing: 12) {
                            PhotoPickerButton(onPicked: { router.present(image: $0) }) {
                                Label("Choose Photo", systemImage: "photo")
                            }
                            .buttonStyle(GhostButtonStyle())

                            Button { router.tab = .ask } label: {
                                Label("Ask PORTAL", systemImage: "text.bubble")
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                    }

                    statusCard
                    discoveries
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .foregroundStyle(.white)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "System status")
            statusRow(
                title: "Language model",
                value: languageStatus,
                color: vm.phase == .ready ? Theme.cyan : Theme.secondaryText
            )
            statusRow(title: "Visual analysis", value: "Not connected yet", color: Theme.secondaryText)
            statusRow(title: "Processing", value: "On this iPhone, no cloud", color: Theme.cyan)
            if vm.phase != .ready {
                Button("Load language model") { router.showModelSheet = true }
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private var languageStatus: String {
        switch vm.phase {
        case .ready: return "\(vm.selectedModelName) · ready"
        case .loading(let fraction): return fraction < 1 ? "Downloading \(Int(fraction * 100))%" : "Loading into memory"
        case .failed: return "Failed to load"
        case .idle: return "Not loaded"
        }
    }

    private func statusRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).foregroundStyle(color).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var discoveries: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Recent discoveries")
            Text("Nothing here yet. Saved discoveries will appear here once visual analysis and memory are added.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }
}
