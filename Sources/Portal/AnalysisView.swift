import SwiftUI

/// What each on-device tool found in a photo from the chat. Every section is labeled with its
/// source, and OCR text is kept separate from detected objects and classifier labels.
/// (The vision model's description and the language model's explanation appear in the chat.)
struct AnalysisView: View {
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
                    }
                    .padding(Theme.Space.m)
                }
            }
            .navigationTitle("Details")
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
        case .done(let analysis, let objects):
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                objectSection(objects)
                textSection(analysis.ocr)
                labelSection(analysis.labels)
                footer(analysis)
            }
        }
    }

    private func objectSection(_ objects: [ObjectDetector.Detection]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            ProvenanceBadge(provenance: .detected)
            Text("Objects found by the on-device detector. It knows 80 common types and can miss or misname things.")
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.secondaryText)
            if objects.isEmpty {
                Text(ObjectDetector.shared.isAvailable ? "No known objects found." : "The detector isn't available in this build.")
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(spacing: 12) {
                    ForEach(objects.sorted(by: { $0.confidence > $1.confidence })) { object in
                        barRow(name: object.label.capitalized, confidence: object.confidence)
                    }
                }
                .padding(.top, Theme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
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
            Text("Scene labels for the whole image from an on-device classifier. They say what it looks like, not where things are.")
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.secondaryText)
            if labels.isEmpty {
                Text("No confident labels.")
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(spacing: 12) {
                    ForEach(labels) { label in
                        barRow(name: label.name, confidence: label.confidence)
                    }
                }
                .padding(.top, Theme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }

    private func barRow(name: String, confidence: Float) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(name).font(Theme.Typeface.secondary)
                Spacer()
                Text("\(Int((confidence * 100).rounded()))%")
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
                            .frame(width: proxy.size.width * CGFloat(confidence))
                    }
                }
        }
    }

    private func footer(_ analysis: ImageAnalysis) -> some View {
        Text("Analyzed on this iPhone in \(String(format: "%.2f s", analysis.totalSeconds)) (text and labels). The vision model's description and the explanation are in the chat.")
            .font(Theme.Typeface.caption)
            .foregroundStyle(Theme.tertiaryText)
    }
}
