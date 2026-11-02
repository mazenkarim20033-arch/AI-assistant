import SwiftUI

/// A slim, icon-only navigation bar. Selection is shown by a white icon and a small cyan dot.
struct PortalTabBar: View {
    @Binding var selection: PortalRouter.Tab

    private struct Item {
        let tab: PortalRouter.Tab
        let icon: String
        let label: String
    }

    private let items = [
        Item(tab: .explore, icon: "viewfinder", label: "Explore"),
        Item(tab: .ask, icon: "bubble.left.and.bubble.right", label: "Ask"),
        Item(tab: .discover, icon: "sparkle.magnifyingglass", label: "Discover"),
        Item(tab: .memory, icon: "brain", label: "Memory"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button { selection = item.tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 21, weight: .light))
                        Circle()
                            .fill(selection == item.tab ? Theme.cyan : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(selection == item.tab ? Color.white : Theme.tertiaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(item.label)
            }
        }
        .padding(.top, Theme.Space.xs)
        .background(Theme.background.opacity(0.94))
    }
}
