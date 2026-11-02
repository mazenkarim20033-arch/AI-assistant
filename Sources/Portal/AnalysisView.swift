import SwiftUI

/// Shows the chosen image and, for now, an honest "analysis not connected" status
/// together with how findings will be labeled once analysis exists.
struct AnalysisView: View {
    @EnvironmentObject var vm: AgentViewModel
    @EnvironmentObject var router: PortalRouter

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        imageCard
                        statusCard
                        actions
                    }
                    .padding(Theme.Space.m)
                }
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { router.showAnalysis = false }
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var imageCard: some View {
        if let image = router.currentImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    /// Status and the four finding labels in one quiet panel.
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Analysis isn't connected yet")
                .font(Theme.Typeface.title)
            Text("PORTAL can show this image and keep it in the conversation, but it can't read or describe it yet. When analysis arrives, every finding will be labeled by where it came from:")
                .font(Theme.Typeface.secondary)
                .foregroundStyle(Theme.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Provenance.allCases, id: \.self) { provenance in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                        ProvenanceBadge(provenance: provenance)
                            .frame(width: 112, alignment: .leading)
                        Text(provenance.detail)
                            .font(Theme.Typeface.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .padding(.top, Theme.Space.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private var actions: some View {
        VStack(spacing: Theme.Space.s) {
            Button {
                if let image = router.currentImage { vm.attachImage(image) }
                router.showAnalysis = false
                router.tab = .ask
            } label: {
                Label("Add to conversation", systemImage: "text.bubble")
            }
            .buttonStyle(PortalButtonStyle())

            HStack(spacing: Theme.Space.s) {
                Button { router.reopenCamera() } label: {
                    Label("Retake", systemImage: "camera")
                }
                .buttonStyle(GhostButtonStyle())

                PhotoPickerButton(onPicked: { router.currentImage = $0 }) {
                    Label("Choose another", systemImage: "photo")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
}
