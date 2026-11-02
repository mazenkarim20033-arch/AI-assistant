import SwiftUI

/// Everything PORTAL has saved on this phone. Today that is the notes the agent saves for you.
struct MemoryView: View {
    @EnvironmentObject var vm: AgentViewModel

    var body: some View {
        NavigationStack {
            NotesList(store: vm.notes)
                .navigationTitle("Memory")
                .navigationBarTitleDisplayMode(.inline)
        }
        .foregroundStyle(.white)
    }
}

private struct NotesList: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        List {
            Section {
                ForEach(store.notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text)
                        Text(note.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .listRowBackground(Theme.panel)
                }
                .onDelete(perform: store.delete)
            } header: {
                SectionLabel(text: "Saved notes")
            } footer: {
                Text("Stored only on this iPhone. Swipe a note to delete it. Conversation history and saved discoveries will be added later.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .overlay {
            if store.notes.isEmpty {
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Ask PORTAL to remember something.")
                )
            }
        }
    }
}
