import MLX
import UIKit

/// How a photo is understood. The tools take turns because the vision model and the language model
/// don't fit in memory together on an iPhone 15:
///   - When a photo is shared, only the small tools run (object detector, text recognition). Nothing is
///     written about the photo; it just joins the chat.
///   - On the first question about it, the vision model looks at the photo with that question in mind
///     (the language model is unloaded for this), then the language model is reloaded and answers from
///     the labeled notes plus its own knowledge.
///   - Later questions use the saved notes. If one needs more detail, the language model can ask for
///     another look ("[LOOK: ...]"), which repeats the vision step.
extension AgentViewModel {
    /// Called for every photo the user takes or picks.
    func startPhoto(_ image: UIImage) {
        guard !isThinking else {
            feed.append(.notice(id: UUID(), text: "Still working on the last request. Try the photo again in a moment."))
            return
        }
        isThinking = true
        generation = Task {
            defer { self.isThinking = false }
            await self.processPhoto(image)
        }
    }

    private func processPhoto(_ image: UIImage) async {
        feed.append(.image(id: UUID(), image: image))
        let noticeID = UUID()
        feed.append(.notice(id: noticeID, text: "Looking at the photo…"))
        currentPhoto = image
        photoNeedsLook = true

        let analysis = try? await AppleVisionAnalyzer.analyze(image)
        let objects = await ObjectDetector.detect(image)
        let ocr = analysis?.ocr.text ?? ""
        currentOCR = ocr
        currentObjects = objects
        currentLabels = analysis?.labels ?? []
        photoContext = Self.buildContext(objects: objects, labels: currentLabels, ocr: ocr, description: nil)

        let names = Array(Set(objects.map(\.label))).sorted().prefix(4).joined(separator: ", ")
        setNotice(noticeID, names.isEmpty
            ? "Photo added. Ask me anything about it."
            : "Photo added · detected: \(names). Ask me anything about it.")
    }

    /// The first question about a new photo: one look with the vision model aimed at the question,
    /// then the language model answers.
    func answerAboutPhoto(_ request: String) async {
        photoNeedsLook = false
        guard let image = currentPhoto else {
            await streamReply(to: request)
            return
        }

        let noticeID = UUID()
        feed.append(.notice(id: noticeID, text: "Looking at your photo…"))
        var description: String?
        if let vision {
            description = await visionLook(
                image: image,
                question: Self.targetedLook(for: request),
                ocr: currentOCR ?? "",
                noticeID: noticeID,
                vision: vision
            )
        }
        guard !Task.isCancelled else { setNotice(noticeID, "Stopped."); return }

        let context = Self.buildContext(objects: currentObjects, labels: currentLabels, ocr: currentOCR ?? "", description: description)
        photoContext = context
        setNotice(noticeID, description == nil
            ? "Answering from the object detector and text reading only."
            : "Looked closely with the vision model.")

        guard await ensureLanguageModel() else {
            setNotice(noticeID, "The language model isn't ready. Tap the status line on Home to load it.")
            return
        }

        let prompt = """
            The user shared a photo and asks: \(request)

            You cannot see the photo. Notes from the app's vision tools:
            \(context)

            Answer the question. You may use your general knowledge (for example how this kind of device is \
            normally used), but keep what the notes show separate from what you assume, and say if you are \
            unsure or need the model name or more detail.
            """
        await streamReply(to: prompt, allowLook: false)
    }

    /// The language model asked for another look at the photo with a specific question.
    func lookAgain(question: String) async {
        guard let image = currentPhoto, let vision else { return }
        let noticeID = UUID()
        feed.append(.notice(id: noticeID, text: "Taking a closer look…"))
        let answer = await visionLook(image: image, question: question, ocr: currentOCR ?? "", noticeID: noticeID, vision: vision)
        guard !Task.isCancelled else { setNotice(noticeID, "Stopped."); return }
        setNotice(noticeID, answer == nil ? "Couldn't look closer." : "Looked closer with the vision model.")

        guard await ensureLanguageModel() else { return }
        let followUp: String
        if let answer {
            followUp = """
                The app looked at the photo again for you.
                Question it asked: \(question)
                Vision model's answer (can be wrong): \(answer)

                Now answer the user's last question using this. Say what you are unsure about.
                """
        } else {
            followUp = "The app could not look closer. Answer the user's last question as well as you can from your notes, and say what you are unsure about."
        }
        await streamReply(to: followUp, allowLook: false)
    }

    /// Asks the vision model to describe what is relevant to the user's question. Its job is to report
    /// what is visible, not to answer; the language model answers.
    private static func targetedLook(for question: String) -> String {
        """
        The user asks: "\(question)". Describe only what is visible in the image that helps answer: what the \
        object is (its type, and brand or model if readable), its controls such as buttons, switches and ports \
        with their colours, positions (left, right, top, bottom) and any labels or symbols. Be specific and \
        brief, under 150 words.
        """
    }

    /// Runs the vision model on the photo. Returns its description, or nil if it was skipped or failed.
    /// The language model is unloaded meanwhile and reloaded afterwards. If the language model's memory
    /// can't be freed, the look is skipped rather than risking the app being closed.
    private func visionLook(image: UIImage, question: String, ocr: String, noticeID: UUID, vision: VisionModelService) async -> String? {
        if !vision.isReady, !vision.hasDownloaded {
            let proceed = await askDecision(
                "Look closely with the vision model? One-time download, \(vision.option.size). It stays on this iPhone.",
                confirm: "Download",
                cancel: "Skip"
            )
            guard proceed else { return nil }
        }

        setNotice(noticeID, vision.hasDownloaded ? "Looking closely…" : "Getting the vision model…")
        suspendForVision()
        guard await memoryIsFree() else {
            setNotice(noticeID, "Couldn't free enough memory to look closer.")
            await resumeAfterVision()
            return nil
        }

        // Keep the progress line current while the vision model downloads or loads.
        let watcher = Task { @MainActor in
            while !Task.isCancelled {
                if case .loading(let fraction) = vision.phase {
                    self.setNotice(noticeID, fraction < 1 ? "Downloading the vision model… \(Int(fraction * 100))%" : "Waking the vision model…")
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        await vision.load()
        watcher.cancel()

        var text: String?
        if vision.isReady, !Task.isCancelled {
            setNotice(noticeID, "Looking closely…")
            if let stream = vision.ask(question, frame: image, ocrText: ocr) {
                var collected = ""
                do {
                    for try await chunk in stream { collected += chunk }
                } catch {
                    // keep whatever arrived
                }
                text = collected.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        vision.unload()
        _ = await memoryIsFree()
        setNotice(noticeID, "Waking the language model…")
        await resumeAfterVision()
        return (text ?? "").isEmpty ? nil : text
    }

    /// Waits (up to about 3 seconds) until the memory MLX holds has dropped, so the next model can
    /// load. Returns false if it never did.
    private func memoryIsFree() async -> Bool {
        let limit = 700 * 1024 * 1024
        for _ in 0..<20 {
            Memory.clearCache()
            if Memory.activeMemory < limit { return true }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return Memory.activeMemory < limit
    }

    /// Waits for the language model to be ready, loading it if needed.
    func ensureLanguageModel() async -> Bool {
        for _ in 0..<240 {
            switch phase {
            case .ready:
                return true
            case .loading:
                try? await Task.sleep(nanoseconds: 500_000_000)
            case .idle, .failed:
                await loadModel()
                if phase != .ready { return false }
            }
        }
        return phase == .ready
    }

    /// The notes handed to the language model, each labeled with where it came from.
    private static func buildContext(objects: [ObjectDetector.Detection], labels: [ClassificationLabel], ocr: String, description: String?) -> String {
        var parts: [String] = []

        if objects.isEmpty {
            parts.append("OBJECT DETECTOR: found no objects it recognizes (it only knows 80 common types).")
        } else {
            let list = objects.sorted { $0.confidence > $1.confidence }.prefix(10)
                .map { "\($0.label) (\(Int(($0.confidence * 100).rounded()))%)" }
                .joined(separator: ", ")
            parts.append("OBJECT DETECTOR (names with confidence; can miss or misname things): \(list)")
        }
        if !labels.isEmpty {
            let list = labels.prefix(4).map { "\($0.name) (\(Int(($0.confidence * 100).rounded()))%)" }.joined(separator: ", ")
            parts.append("SCENE LABELS (image classifier): \(list)")
        }
        let trimmedOCR = ocr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOCR.isEmpty {
            parts.append("TEXT READ BY OCR (may contain mistakes): \(String(trimmedOCR.prefix(500)))")
        }
        if let description, !description.isEmpty {
            parts.append("VISION MODEL DESCRIPTION (can be wrong): \(String(description.prefix(700)))")
        }
        return parts.joined(separator: "\n")
    }
}
