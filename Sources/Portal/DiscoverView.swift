import SwiftUI

/// Discover will show saved observations and learning history once analysis and memory exist.
/// Until then it is an honest, quiet placeholder, not sample data.
struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: Theme.Space.s) {
                    Spacer()
                    PortalOrb(size: 130)
                    Text("Nothing discovered yet")
                        .font(Theme.Typeface.title)
                        .padding(.top, Theme.Space.s)
                    Text("Things PORTAL identifies and explanations you save will gather here.")
                        .font(Theme.Typeface.secondary)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Space.xl)
                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
        }
        .foregroundStyle(.white)
    }
}
