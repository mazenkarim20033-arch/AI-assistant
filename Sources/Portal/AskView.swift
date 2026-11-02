import SwiftUI

/// The conversation: user messages, images, notices, action cards. The agent behind it is
/// unchanged (one JSON action per request, validated and run in Swift).
struct AskView: View {
    @EnvironmentObject var vm: AgentViewModel
    @EnvironmentObject var router: PortalRouter
    @State private var input = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    feed
                    if vm.phase == .ready {
                        composer
                    } else {
                        loadPrompt
                    }
                }
            }
            .navigationTitle("Ask PORTAL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.phase == .ready {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { vm.unloadModel() } label: { Image(systemName: "cpu") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.clearFeed() } label: { Image(systemName: "trash") }
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.feed.isEmpty {
                        VStack(spacing: 14) {
                            PortalOrb(size: 110, thinking: false)
                            Text("Tell me what to do.")
                                .font(.headline)
                            Text("Try: \"remember that my locker code is 4821\"")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.top, 50)
                    }
                    ForEach(vm.feed) { item in
                        FeedRow(item: item).id(item.id)
                    }
                    if vm.isThinking {
                        HStack {
                            PortalOrb(size: 36, thinking: true)
                            Text("Working…").font(.footnote).foregroundStyle(Theme.secondaryText)
                            Spacer()
                        }
                        .id("thinking")
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.feed.count) {
                if let last = vm.feed.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PhotoPickerButton(onPicked: { vm.attachImage($0) }) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(Theme.panel, in: Circle())
            }
            TextField("What should I do?", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke))
            Button {
                vm.submit(input)
                input = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Theme.blue, in: Circle())
            }
            .disabled(vm.isThinking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(vm.isThinking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var loadPrompt: some View {
        VStack(spacing: 10) {
            Text("The language model isn't loaded.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Button("Load language model") { router.showModelSheet = true }
                .buttonStyle(PortalButtonStyle())
        }
        .padding(16)
    }
}

private struct FeedRow: View {
    let item: FeedItem

    var body: some View {
        switch item {
        case .user(_, let text):
            HStack {
                Spacer(minLength: 48)
                Text(text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        case .assistant(_, let text):
            HStack {
                Text(text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
                Spacer(minLength: 48)
            }
        case .image(_, let image):
            HStack {
                Spacer(minLength: 80)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        case .notice(_, let text):
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "System")
                Text(text).font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .portalCard(padding: 12)
        case .action(let card):
            ActionCardView(card: card)
        }
    }
}

private struct ActionCardView: View {
    let card: ActionCard
    @EnvironmentObject var vm: AgentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundStyle(Theme.cyan)
                Text(card.title).font(.subheadline.weight(.semibold))
            }
            switch card.state {
            case .pending:
                HStack(spacing: 10) {
                    Button("Cancel") { vm.cancel(card.id) }
                        .buttonStyle(GhostButtonStyle())
                    Button("Confirm") { vm.confirm(card.id) }
                        .buttonStyle(PortalButtonStyle())
                }
            case .running:
                ProgressView()
            case .done(let result):
                Text(result).font(.subheadline).foregroundStyle(Theme.cyan)
            case .failed(let message):
                Text(message).font(.subheadline).foregroundStyle(.red)
            case .cancelled:
                Text("Cancelled").font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }
}
