import SwiftUI

/// The one main screen. Before you say anything it shows the orb and a greeting; once a
/// conversation starts, the conversation takes over the same space. One input at the bottom,
/// plus a camera shortcut. Everything else is one tap away in the menu.
struct HomeView: View {
    @EnvironmentObject var vm: AgentViewModel
    @EnvironmentObject var router: PortalRouter
    @State private var input = ""
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sends the typed request. If the model isn't ready, opens the model sheet and keeps the text.
    private func send() {
        guard canSend else { return }
        guard vm.phase == .ready else {
            router.showModelSheet = true
            return
        }
        vm.submit(input)
        input = ""
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.violet.opacity(0.16), .clear],
                center: .top, startRadius: 10, endRadius: 460
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if vm.feed.isEmpty {
                    welcome
                } else {
                    conversation
                }

                interactionBar
                    .padding(.horizontal, Theme.Space.m)
                    .padding(.vertical, Theme.Space.s)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: focused)
        .animation(.easeInOut(duration: 0.25), value: vm.feed.isEmpty)
        .foregroundStyle(.white)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Text("PORTAL")
                .font(.system(size: 13, weight: .regular))
                .tracking(9)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Menu {
                Button("New conversation", systemImage: "square.and.pencil") { vm.newConversation() }
                Button("Intelligence", systemImage: "cpu") { router.showModelSheet = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, Theme.Space.s)
    }

    // MARK: Welcome (no conversation yet)

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            // Shrinks while typing so the keyboard doesn't crush the layout.
            PortalOrb(size: focused ? 120 : 240, thinking: vm.isThinking)
                .onTapGesture { focused = false }

            VStack(spacing: Theme.Space.s) {
                Text(greeting)
                    .font(Theme.Typeface.display)
                statusLine
            }
            .padding(.top, Theme.Space.l)
            Spacer()
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        case 18..<23: return "Good evening"
        default: return "Hello"
        }
    }

    /// One quiet line. Tapping it opens the model and system details.
    private var statusLine: some View {
        Button { router.showModelSheet = true } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.phase == .ready ? Theme.cyan : Theme.tertiaryText)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(Theme.Typeface.secondary)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var statusText: String {
        switch vm.phase {
        case .ready: return "On this iPhone · \(vm.selectedModelName)"
        case .loading(let fraction): return fraction < 1 ? "Downloading \(Int(fraction * 100))%" : "Waking up…"
        case .failed: return "Couldn't load · tap for details"
        case .idle: return "Tap to wake PORTAL"
        }
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Space.s) {
                    ForEach(vm.feed) { item in
                        FeedRow(item: item).id(item.id)
                    }
                }
                .padding(Theme.Space.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.feed.count) {
                if let last = vm.feed.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: lastText) {
                if let last = vm.feed.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    /// Changes as a streaming reply grows, so the view keeps following it.
    private var lastText: String {
        guard let last = vm.feed.last, case .assistant(_, let text) = last else { return "" }
        return text
    }

    // MARK: Input

    private var interactionBar: some View {
        HStack(spacing: Theme.Space.s) {
            HStack(spacing: 0) {
                TextField("Ask PORTAL…", text: $input)
                    .font(Theme.Typeface.body)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                trailingButton
            }
            .padding(.leading, Theme.Space.m)
            .padding(.trailing, Theme.Space.xs)
            .frame(height: 56)
            .background(Theme.panel, in: Capsule())

            Button { router.showCamera = true } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.signature))
                    .shadow(color: Theme.blue.opacity(0.4), radius: 14)
            }
            .accessibilityLabel("Open camera")
        }
    }

    /// Stop while a reply is being written, send when there is text, otherwise the photo picker.
    @ViewBuilder
    private var trailingButton: some View {
        if vm.isThinking {
            Button { vm.stopGenerating() } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Stop")
        } else if canSend {
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.signature)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Send")
        } else {
            PhotoPickerButton(onPicked: { router.present(image: $0) }) {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 36, height: 36)
            }
        }
    }
}
