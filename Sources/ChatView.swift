import SwiftUI

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @State private var input = ""

    var body: some View {
        NavigationStack {
            Group {
                if vm.phase == .ready {
                    chat
                } else {
                    SetupView(vm: vm)
                }
            }
            .navigationTitle("Local Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.phase == .ready {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { vm.unloadModel() } label: { Image(systemName: "cpu") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { vm.newChat() } label: { Image(systemName: "square.and.pencil") }
                    }
                }
            }
        }
    }

    private var chat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.messages) { message in
                            Bubble(message: message).id(message.id)
                        }
                    }
                    .padding(12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.messages.last?.text) {
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            composer
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            Button {
                if vm.isGenerating {
                    vm.stop()
                } else {
                    vm.send(input)
                    input = ""
                }
            } label: {
                Image(systemName: vm.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 34))
            }
            .disabled(!vm.isGenerating && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct Bubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text.isEmpty ? "…" : message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user ? Color.blue : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .textSelection(.enabled)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

private struct SetupView: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        Form {
            Section("Model") {
                Picker("Model", selection: $vm.selectedModelID) {
                    ForEach(ModelOption.all) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("System prompt") {
                TextField("System prompt", text: $vm.systemPrompt, axis: .vertical)
                    .lineLimit(2...6)
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
