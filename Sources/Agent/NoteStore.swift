import Foundation

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var date = Date()
}

/// Notes saved on the phone (Documents/notes.json). Search is plain keyword matching,
/// so the small model never has to read the notes itself.
@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("notes.json")
        load()
    }

    @discardableResult
    func add(_ text: String) -> Note {
        let note = Note(text: text)
        notes.insert(note, at: 0)
        save()
        return note
    }

    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        save()
    }

    func latest(_ limit: Int = 5) -> [Note] {
        Array(notes.prefix(limit))
    }

    func search(_ query: String, limit: Int = 5) -> [Note] {
        let ignored: Set<String> = [
            "the", "an", "is", "are", "what", "whats", "my", "of", "to", "and", "for",
            "me", "about", "did", "was", "where", "who", "when", "do", "does", "have",
        ]
        let tokens = query.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 && !ignored.contains($0) }
        guard !tokens.isEmpty else { return [] }

        let scored = notes.map { note -> (note: Note, score: Int) in
            let text = note.text.lowercased()
            return (note, tokens.filter { text.contains($0) }.count)
        }
        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.note.date > $1.note.date }
            .prefix(limit)
            .map { $0.note }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data)
        else { return }
        notes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
