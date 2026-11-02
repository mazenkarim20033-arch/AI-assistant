import SwiftUI

/// Model picker, loader and system status (the details that used to crowd the home screen).
struct ModelSheet: View {
    @EnvironmentObject var vm: AgentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Space.l) {
                        PortalOrb(size: 130, thinking: isLoading)
                            .padding(.top, Theme.Space.xs)

                        statusArea

                        modelList

                        systemList
                    }
                    .padding(Theme.Space.m)
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

    private var modelList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            SectionLabel(text: "Language model")
                .padding(.bottom, Theme.Space.xs)
            ForEach(ModelOption.all) { option in
                Button { vm.selectedModelID = option.id } label: {
                    HStack {
                        Text(option.name).font(Theme.Typeface.secondary)
                        Spacer()
                        if vm.selectedModelID == option.id {
                            Image(systemName: "checkmark").foregroundStyle(Theme.cyan)
                        }
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.white)
                .disabled(isLoading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private var systemList: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionLabel(text: "System")
            row("Language model", languageStatus, vm.phase == .ready ? Theme.cyan : Theme.secondaryText)
            row("Text and labels", "Apple Vision · ready", Theme.cyan)
            row("Vision model", "Not added yet", Theme.secondaryText)
            row("Processing", "On this iPhone, no cloud", Theme.cyan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private func row(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).foregroundStyle(color).multilineTextAlignment(.trailing)
        }
        .font(Theme.Typeface.secondary)
    }

    private var languageStatus: String {
        switch vm.phase {
        case .ready: return "\(vm.selectedModelName) · ready"
        case .loading(let fraction): return fraction < 1 ? "Downloading \(Int(fraction * 100))%" : "Loading into memory"
        case .failed: return "Failed to load"
        case .idle: return "Not loaded"
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        switch vm.phase {
        case .loading(let fraction):
            VStack(spacing: Theme.Space.xs) {
                ProgressView(value: fraction).tint(Theme.cyan)
                Text(fraction < 1 ? "Downloading… \(Int(fraction * 100))%" : "Loading into memory…")
                    .font(Theme.Typeface.caption).foregroundStyle(Theme.secondaryText)
            }
        case .failed(let message):
            VStack(spacing: Theme.Space.s) {
                Text("Failed: \(message)").font(Theme.Typeface.caption).foregroundStyle(.red)
                loadButton
            }
        case .idle, .ready:
            VStack(spacing: Theme.Space.xs) {
                loadButton
                Text("Downloads once, then runs entirely on this iPhone.")
                    .font(Theme.Typeface.caption).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var loadButton: some View {
        Button("Download & load model") { Task { await vm.loadModel() } }
            .buttonStyle(PortalButtonStyle())
    }
}
