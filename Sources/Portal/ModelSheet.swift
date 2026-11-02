import SwiftUI

/// Model picker and loader (the original setup screen, restyled).
struct ModelSheet: View {
    @EnvironmentObject var vm: AgentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        PortalOrb(size: 120, thinking: isLoading)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Language model")
                            ForEach(ModelOption.all) { option in
                                Button { vm.selectedModelID = option.id } label: {
                                    HStack {
                                        Text(option.name).font(.subheadline)
                                        Spacer()
                                        if vm.selectedModelID == option.id {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.cyan)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .foregroundStyle(.white)
                                .disabled(isLoading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .portalCard()

                        statusArea

                        Text("The model downloads once, then runs entirely on this iPhone.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onChange(of: vm.phase) {
            if vm.phase == .ready { dismiss() }
        }
    }

    private var isLoading: Bool {
        if case .loading = vm.phase { return true }
        return false
    }

    @ViewBuilder
    private var statusArea: some View {
        switch vm.phase {
        case .loading(let fraction):
            VStack(spacing: 8) {
                ProgressView(value: fraction).tint(Theme.cyan)
                Text(fraction < 1 ? "Downloading… \(Int(fraction * 100))%" : "Loading into memory…")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        case .failed(let message):
            VStack(spacing: 10) {
                Text("Failed: \(message)").font(.footnote).foregroundStyle(.red)
                loadButton
            }
        case .idle, .ready:
            loadButton
        }
    }

    private var loadButton: some View {
        Button("Download & load model") { Task { await vm.loadModel() } }
            .buttonStyle(PortalButtonStyle())
    }
}
