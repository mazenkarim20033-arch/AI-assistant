import SwiftUI

/// One entry in the conversation. New kinds of result get their own case here and in `FeedItem`,
/// so adding a capability never needs a new screen.
struct FeedRow: View {
    let item: FeedItem
    @EnvironmentObject var router: PortalRouter

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
                Text(text.isEmpty ? "…" : text)
                    .font(Theme.Typeface.body)
                    .foregroundStyle(text.isEmpty ? Theme.tertiaryText : Color.white)
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
                    .onTapGesture { router.showDetails(for: image) }   // what each tool found
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

/// A tool action: shows what is about to happen, asks for Confirm when it changes something,
/// then shows the result. Not used until the first tool is registered.
struct ActionCardView: View {
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
                    Button(card.cancelLabel) { vm.cancel(card.id) }
                        .buttonStyle(GhostButtonStyle())
                    Button(card.confirmLabel) { vm.confirm(card.id) }
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
