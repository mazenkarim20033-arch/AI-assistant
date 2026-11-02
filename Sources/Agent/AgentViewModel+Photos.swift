import UIKit

/// How a photo is understood. The tools take turns because the vision model and the language model
/// don't fit in memory together on an iPhone 15:
///   1. object detector + text recognition (small, run while the language model stays loaded),
///   2. the vision model describes the photo (the language model is unloaded for this),
///   3. the language model is reloaded and explains the photo from all of those notes.
/// Later questions use the saved notes; if they need more detail the language model can ask for another
/// look, which runs step 2 again with a specific question.
extension AgentViewModel {
    private static let generalLookQuestion = """
        Describe this image in detail: the main objects, their colours and positions (left, right, top, bottom), \
        any buttons, labels, symbols or text, and what the scene is. Be specific and brief, under 120 words.
        """

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
        feed.append(.notice(id: noticeID, text: "Detecting objects and reading text…"))
        currentPhoto = image
        photoContext = nil

        // 1. Small on-device tools.
        let analysis = try? await AppleVisionAnalyzer.analyze(image)
        let objects = await ObjectDetector.detect(image)
        let ocr = analysis?.ocr.text ?? ""
        currentOCR = ocr
        guard !Task.isCancelled else { setNotice(noticeID, "Stopped."); return }

        // 2. The vision model's description.
        var description: String?
        if let vision {
            description = await visionLook(image: image, question: Self.generalLookQuestion, ocr: ocr, noticeID: noticeID, vision: vision)
        }
        guard !Task.isCancelled else { setNotice(noticeID, "Stopped."); return }

        // 3. The language model explains, from the notes.
        let context = Self.buildContext(objects: objects, labels: analysis?.labels ?? [], ocr: ocr, description: description)
        photoContext = context
        setNotice(noticeID, "Writing the explanation…")
        guard await ensureLanguageModel(), let session = chatSession else {
            setNotice(noticeID, "The language model isn't ready. Tap the status line on Home to load it.")
            return
        }

        var used: [String] = []
        if !objects.isEmpty { used.append("object detector (\(objects.count))") }
        if !ocr.isEmpty { used.append("text recognition") }
        if description != nil { used.append("vision model") }
        setNotice(noticeID, used.isEmpty ? "No tool found anything clear in this photo." : "Notes from: " + used.joined(separator: ", ") + ". Tap the photo for details.")

        let prompt = """
            The user just shared a photo. You cannot see it. Here is what the app's vision tools found:

            \(context)

            Explain what is in the photo in 3 to 5 short sentences. Say which parts are certain and which are \
            guesses. Then invite the user to ask about anything specific.
            """
        transcript.append(Turn(isUser: true, text: "(shared a photo)"))
        await streamReply(to: prompt, using: session, allowLook: false)
    }

    /// The language model asked for another look at the photo with a specific question.
    func lookAgain(question: String) async {
        guard let image = currentPhoto, let vision else { return }
        let noticeID = UUID()
        feed.append(.notice(id: noticeID, text: "Taking a closer look…"))
        let answer = await visionLook(image: image, question: question, ocr: currentOCR ?? "", noticeID: noticeID, vision: vision)
        guard !Task.isCancelled else { setNotice(noticeID, "Stopped."); return }
        setNotice(noticeID, answer == nil ? "Couldn't look closer." : "Looked closer with the vision model.")

        guard await ensureLanguageModel(), let session = chatSession else { return }
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
        await streamReply(to: followUp, using: session, allowLook: false)
    }

    /// Runs the vision model on the photo. Returns its answer, or nil if it was skipped or failed.
    /// The language model is unloaded meanwhile and reloaded afterwards.
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
        setNotice(noticeID, "Waking the language model…")
        await resumeAfterVision()
        return (text ?? "").isEmpty ? nil : text
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
