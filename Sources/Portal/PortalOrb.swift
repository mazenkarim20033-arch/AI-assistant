import SwiftUI

/// The central intelligence indicator. Rotating rings plus a breathing core;
/// `thinking` adds an outer pulse ring while the model is working.
struct PortalOrb: View {
    var size: CGFloat = 200
    var thinking = false

    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.violet.opacity(0.35), .clear],
                    center: .center, startRadius: size * 0.05, endRadius: size * 0.7
                ))
                .blur(radius: 18)
                .scaleEffect(breathe ? 1.1 : 0.92)

            Circle()
                .strokeBorder(
                    AngularGradient(colors: [Theme.cyan, Theme.blue, Theme.violet, Theme.cyan], center: .center),
                    lineWidth: 2
                )
                .rotationEffect(.degrees(spin ? 360 : 0))

            Circle()
                .inset(by: size * 0.08)
                .strokeBorder(Theme.blue.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                .rotationEffect(.degrees(spin ? -360 : 0))

            if thinking {
                Circle()
                    .strokeBorder(Theme.cyan.opacity(0.5), lineWidth: 1)
                    .scaleEffect(breathe ? 1.12 : 0.98)
                    .opacity(breathe ? 0.1 : 0.7)
            }

            Circle()
                .fill(RadialGradient(
                    colors: [Theme.cyan.opacity(0.95), Theme.blue.opacity(0.65), .black],
                    center: .center, startRadius: 2, endRadius: size * 0.26
                ))
                .frame(width: size * 0.36, height: size * 0.36)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 14)
                .scaleEffect(breathe ? 1.07 : 0.94)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}
