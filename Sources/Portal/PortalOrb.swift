import SwiftUI

/// The central intelligence indicator: a soft glow, one gradient ring and a breathing core.
/// The app icon uses the same composition. `thinking` adds a slow pulse ring while the model works.
struct PortalOrb: View {
    var size: CGFloat = 200
    var thinking = false

    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.violet.opacity(0.30), .clear],
                    center: .center, startRadius: size * 0.05, endRadius: size * 0.62
                ))
                .blur(radius: size * 0.08)
                .scaleEffect(breathe ? 1.06 : 0.94)

            Circle()
                .inset(by: size * 0.16)
                .strokeBorder(
                    AngularGradient(
                        colors: [Theme.cyan, Theme.blue, Theme.violet, Theme.cyan],
                        center: .center
                    ),
                    lineWidth: max(1.5, size * 0.012)
                )
                .rotationEffect(.degrees(spin ? 360 : 0))

            if thinking {
                Circle()
                    .inset(by: size * 0.08)
                    .strokeBorder(Theme.cyan.opacity(0.4), lineWidth: 1)
                    .scaleEffect(breathe ? 1.08 : 0.97)
                    .opacity(breathe ? 0.05 : 0.6)
            }

            Circle()
                .fill(RadialGradient(
                    colors: [Theme.cyan.opacity(0.9), Theme.blue.opacity(0.55), .clear],
                    center: .center, startRadius: 1, endRadius: size * 0.2
                ))
                .frame(width: size * 0.4, height: size * 0.4)
                .scaleEffect(breathe ? 1.06 : 0.94)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}
