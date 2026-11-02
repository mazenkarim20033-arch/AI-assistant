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
                            .font(Theme.Typeface.body)
                        Text(note.date, style: .date)
                            .font(Theme.Typeface.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Theme.panel)
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: store.delete)
            } footer: {
                Text("Stored only on this iPhone. Swipe a note to delete it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .overlay {
            if store.notes.isEmpty {
                VStack(spacing: Theme.Space.s) {
                    Text("Nothing saved yet")
                        .font(Theme.Typeface.title)
                    Text("Ask PORTAL to remember something.")
                        .font(Theme.Typeface.secondary)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}
