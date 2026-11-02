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
                    VStack(alignment: .leading, spacing: 20) {
                        imageCard
                        statusCard
                        legendCard
                        actions
                    }
                    .padding(20)
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
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    CornerBrackets(length: 22)
                        .stroke(Theme.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .padding(8)
                )
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Analysis status")
            Text("Visual analysis is not connected yet.")
                .font(.headline)
            Text("This version can show your image and keep it in the conversation, but it can't read or describe it. Text recognition and object labels come first, then a vision model.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "How findings will be labeled")
            ForEach(Provenance.allCases, id: \.self) { provenance in
                HStack(alignment: .top, spacing: 12) {
                    ProvenanceBadge(provenance: provenance)
                        .frame(width: 112, alignment: .leading)
                    Text(provenance.detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                if let image = router.currentImage { vm.attachImage(image) }
                router.showAnalysis = false
                router.tab = .ask
            } label: {
                Label("Add to conversation", systemImage: "text.bubble")
            }
            .buttonStyle(PortalButtonStyle())

            Button { router.reopenCamera() } label: {
                Label("Take another photo", systemImage: "camera")
            }
            .buttonStyle(GhostButtonStyle())

            PhotoPickerButton(onPicked: { router.currentImage = $0 }) {
                Label("Choose another image", systemImage: "photo")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }
}
