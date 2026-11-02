import Foundation

struct SaveNoteTool: AgentTool {
    let store: NoteStore
    let name = "save_note"
    let promptLine = #"save_note: remember something. args: {"text": "<what to remember>"}"#
    let examples = [
        (
            "remember that Sam's wifi password is blue42",
            #"{"tool":"save_note","args":{"text":"Sam's wifi password is blue42"}}"#
        ),
    ]
    let needsConfirmation = true

    func summary(for args: [String: String]) -> String {
        "Save note: \(args["text"] ?? "")"
    }

    func run(_ args: [String: String]) async throws -> String {
        guard let text = args["text"]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw ToolError.missingArgument("text")
        }
        store.add(text)
        return "Saved."
    }
}

struct SearchNotesTool: AgentTool {
    let store: NoteStore
    let name = "search_notes"
    let promptLine = #"search_notes: find saved notes, or answer a question from them. args: {"query": "<keywords>"}"#
    let examples = [
        (
            "what's Sam's wifi password?",
            #"{"tool":"search_notes","args":{"query":"Sam wifi password"}}"#
        ),
    ]
    let needsConfirmation = false

    func summary(for args: [String: String]) -> String {
        "Search notes: \(args["query"] ?? "")"
    }

    func run(_ args: [String: String]) async throws -> String {
        guard let query = args["query"], !query.isEmpty else {
            throw ToolError.missingArgument("query")
        }
        let found = store.search(query)
        if found.isEmpty { return "No matching notes." }
        return found.map { "• \($0.text)" }.joined(separator: "\n")
    }
}

struct ListNotesTool: AgentTool {
    let store: NoteStore
    let name = "list_notes"
    let promptLine = #"list_notes: show the latest saved notes. args: {}"#
    let examples = [
        ("show my notes", #"{"tool":"list_notes","args":{}}"#),
    ]
    let needsConfirmation = false

    func summary(for args: [String: String]) -> String {
        "Show latest notes"
    }

    func run(_ args: [String: String]) async throws -> String {
        let latest = store.latest()
        if latest.isEmpty { return "No notes yet." }
        return latest.map { "• \($0.text)" }.joined(separator: "\n")
    }
}
