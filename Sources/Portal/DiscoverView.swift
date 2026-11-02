import SwiftUI

/// Discover will show saved observations and learning history once analysis and memory exist.
/// Until then it is an honest placeholder, not sample data.
struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        PortalOrb(size: 120)
                            .padding(.top, 24)
                        Text("Nothing discovered yet")
                            .font(.title3.weight(.semibold))
                        Text("Analyzed objects, saved explanations and your visual learning history will collect here.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 14) {
                            SectionLabel(text: "Planned")
                            plannedRow("Recently identified objects", "After visual analysis is connected")
                            plannedRow("Saved explanations", "After memory is added")
                            plannedRow("Previously analyzed images", "Only images you choose to save")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .portalCard()
                        .padding(.top, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
        }
        .foregroundStyle(.white)
    }

    private func plannedRow(_ title: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.medium))
            Text(note).font(.footnote).foregroundStyle(Theme.secondaryText)
        }
    }
}
