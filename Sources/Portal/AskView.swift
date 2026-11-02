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
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear conversation", systemImage: "trash") { vm.clearFeed() }
                        if vm.phase == .ready {
                            Button("Change model", systemImage: "cpu") { vm.unloadModel() }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var feed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Space.s) {
                    if vm.feed.isEmpty {
                        VStack(spacing: Theme.Space.s) {
                            PortalOrb(size: 120)
                            Text("What should I do?")
                                .font(Theme.Typeface.title)
                            Text("Try “remember that my locker code is 4821”")
                                .font(Theme.Typeface.secondary)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.top, Theme.Space.xl)
                    }
                    ForEach(vm.feed) { item in
                        FeedRow(item: item).id(item.id)
                    }
                    if vm.isThinking {
                        HStack {
                            PortalOrb(size: 40, thinking: true)
                            Spacer()
                        }
                        .id("thinking")
                    }
                }
                .padding(Theme.Space.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.feed.count) {
                if let last = vm.feed.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var canSend: Bool {
        !vm.isThinking && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.s) {
            HStack(alignment: .bottom, spacing: 0) {
                TextField("Ask PORTAL…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(Theme.Typeface.body)
                    .padding(.vertical, 14)
                PhotoPickerButton(onPicked: { vm.attachImage($0) }) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 36, height: 48)
                }
            }
            .padding(.leading, Theme.Space.m)
            .padding(.trailing, Theme.Space.xs)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

            Button {
                vm.submit(input)
                input = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.signature))
            }
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.35)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
    }

    private var loadPrompt: some View {
        VStack(spacing: Theme.Space.s) {
            if case .loading(let fraction) = vm.phase {
                ProgressView(value: fraction).tint(Theme.cyan)
                Text(fraction < 1 ? "PORTAL is waking up · downloading \(Int(fraction * 100))%" : "PORTAL is waking up…")
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("PORTAL isn't awake yet.")
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
                Button("Load language model") { router.showModelSheet = true }
                    .buttonStyle(PortalButtonStyle())
            }
        }
        .padding(Theme.Space.m)
    }
}

private struct FeedRow: View {
    let item: FeedItem

    var body: some View {
        switch item {
        case .user(_, let text):
            HStack {
                Spacer(minLength: 56)
                Text(text)
                    .font(Theme.Typeface.body)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Theme.signature, in: RoundedRectangle(cornerRadius: Theme.Radius.bubble, style: .continuous))
            }
        case .assistant(_, let text):
            HStack {
                Text(text)
                    .font(Theme.Typeface.body)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.Radius.bubble, style: .continuous))
                Spacer(minLength: 56)
            }
        case .image(_, let image):
            HStack {
                Spacer(minLength: 80)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small + 4, style: .continuous))
            }
        case .notice(_, let text):
            Text(text)
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.m)
        case .action(let card):
            ActionCardView(card: card)
        }
    }
}

private struct ActionCardView: View {
    let card: ActionCard
    @EnvironmentObject var vm: AgentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.cyan)
                Text(card.title)
                    .font(.system(size: 15, weight: .medium))
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
                Text(result).font(Theme.Typeface.secondary).foregroundStyle(Theme.cyan)
            case .failed(let message):
                Text(message).font(Theme.Typeface.secondary).foregroundStyle(.red)
            case .cancelled:
                Text("Cancelled").font(Theme.Typeface.secondary).foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .portalCard()
    }
}
