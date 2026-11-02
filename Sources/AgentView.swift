import SwiftUI

struct AgentView: View {
    @StateObject private var vm = AgentViewModel()

    var body: some View {
        if vm.phase == .ready {
            TabView {
                AgentTab(vm: vm)
                    .tabItem { Label("Agent", systemImage: "sparkles") }
                NotesTab(store: vm.notes)
                    .tabItem { Label("Notes", systemImage: "note.text") }
            }
        } else {
            NavigationStack {
                SetupView(vm: vm)
                    .navigationTitle("Local Assistant")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Agent tab

private struct AgentTab: View {
    @ObservedObject var vm: AgentViewModel
    @State private var input = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                feed
                composer
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { vm.unloadModel() } label: { Image(systemName: "cpu") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.clearFeed() } label: { Image(systemName: "trash") }
                }
            }
        }
    }

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if vm.feed.isEmpty {
                        Text("Tell me what to do.\nTry: \"remember that my locker code is 4821\"")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                    }
                    ForEach(vm.feed) { item in
                        FeedRow(item: item, vm: vm).id(item.id)
                    }
                    if vm.isThinking {
                        ProgressView().id("thinking")
                    }
                }
                .padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.feed.count) {
                if let last = vm.feed.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("What should I do?", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            Button {
                vm.submit(input)
                input = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
            }
            .disabled(vm.isThinking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct FeedRow: View {
    let item: FeedItem
    @ObservedObject var vm: AgentViewModel

    var body: some View {
        switch item {
        case .user(_, let text):
            HStack {
                Spacer(minLength: 40)
                Text(text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 18))
            }
        case .assistant(_, let text):
            HStack {
                Text(text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                Spacer(minLength: 40)
            }
        case .action(let card):
            ActionCardView(card: card, vm: vm)
        }
    }
}

private struct ActionCardView: View {
    let card: ActionCard
    @ObservedObject var vm: AgentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(card.title, systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
            switch card.state {
            case .pending:
                HStack {
                    Button("Cancel", role: .cancel) { vm.cancel(card.id) }
                        .buttonStyle(.bordered)
                    Button("Confirm") { vm.confirm(card.id) }
                        .buttonStyle(.borderedProminent)
                }
            case .running:
                ProgressView()
            case .done(let result):
                Text(result).foregroundStyle(.green)
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            case .cancelled:
                Text("Cancelled").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Notes tab

private struct NotesTab: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text)
                        Text(note.date, style: .date)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: store.delete)
            }
            .overlay {
                if store.notes.isEmpty {
                    ContentUnavailableView(
                        "No notes yet",
                        systemImage: "note.text",
                        description: Text("Ask the agent to remember something.")
                    )
                }
            }
            .navigationTitle("Notes")
        }
    }
}

// MARK: - Setup

private struct SetupView: View {
    @ObservedObject var vm: AgentViewModel

    var body: some View {
        Form {
            Section("Model") {
                Picker("Model", selection: $vm.selectedModelID) {
                    ForEach(ModelOption.all) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                switch vm.phase {
                case .loading(let fraction):
                    ProgressView(value: fraction)
                    Text(fraction < 1 ? "Downloading… \(Int(fraction * 100))%" : "Loading into memory…")
                        .font(.footnote).foregroundStyle(.secondary)
                case .failed(let message):
                    Text("Failed: \(message)").foregroundStyle(.red).font(.footnote)
                    loadButton
                default:
                    loadButton
                }
            } footer: {
                Text("The model downloads once, then runs entirely on this iPhone.")
            }
        }
    }

    private var loadButton: some View {
        Button("Download & load model") { Task { await vm.loadModel() } }
    }
}
