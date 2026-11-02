import SwiftUI

/// Shows the chosen image and what the on-device analyzers found in it. Every section is
/// labeled with its source, and OCR text is kept separate from classifier labels.
struct AnalysisView: View {
    @EnvironmentObject var vm: AgentViewModel
    @EnvironmentObject var router: PortalRouter
    @StateObject private var model = AnalysisViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        imageCard
                        results
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
        .task(id: router.imageToken) {
            await model.analyze(router.currentImage, token: router.imageToken)
        }
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

    @ViewBuilder
    private var results: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: Theme.Space.s) {
                ProgressView()
                Text("Reading the image on this iPhone…")
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            Text("Analysis failed: \(message)")
                .font(Theme.Typeface.secondary)
                .foregroundStyle(.red)
        case .done(let analysis):
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                textSection(analysis.ocr)
                labelSection(analysis.labels)
                footer(analysis)
            }
        }
    }

    private func textSection(_ ocr: OCRResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                ProvenanceBadge(provenance: .ocr)
                Spacer()
                if !ocr.lines.isEmpty {
                    Text("\(Int((ocr.averageConfidence * 100).rounded()))% avg. confidence")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            if ocr.lines.isEmpty {
                Text("No text found in this image.")
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text(ocr.text)
                    .font(Theme.Typeface.body)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private func labelSection(_ labels: [ClassificationLabel]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            ProvenanceBadge(provenance: .detected)
            Text("Labels for the whole image from an on-device classifier. They say what it looks like, not where things are.")
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.secondaryText)
            if labels.isEmpty {
                Text("No confident labels.")
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(spacing: 12) {
                    ForEach(labels) { label in
                        labelRow(label)
                    }
                }
                .padding(.top, Theme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private func labelRow(_ label: ClassificationLabel) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label.name).font(Theme.Typeface.secondary)
                Spacer()
                Text("\(Int((label.confidence * 100).rounded()))%")
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Theme.signature)
                            .frame(width: proxy.size.width * CGFloat(label.confidence))
                    }
                }
        }
    }

    private func footer(_ analysis: ImageAnalysis) -> some View {
        Text("Analyzed on this iPhone in \(seconds(analysis.totalSeconds)) (text \(seconds(analysis.ocrSeconds)), labels \(seconds(analysis.labelSeconds))). A vision model and PORTAL's explanations are not connected yet.")
            .font(Theme.Typeface.caption)
            .foregroundStyle(Theme.tertiaryText)
    }

    private func seconds(_ value: Double) -> String {
        String(format: "%.2f s", value)
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

                PhotoPickerButton(onPicked: { router.setImage($0) }) {
                    Label("Choose another", systemImage: "photo")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
}
