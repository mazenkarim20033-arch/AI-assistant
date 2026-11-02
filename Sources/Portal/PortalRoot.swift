import SwiftUI
import UIKit

struct PortalRoot: View {
    @StateObject private var vm = AgentViewModel()
    @StateObject private var router = PortalRouter()
    @StateObject private var vision = VisionModelService()
    @State private var keyboardVisible = false

    var body: some View {
        // The tab bar is a sibling below the content (not an overlay), so screens never sit behind it.
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(router.tab)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: router.tab)

            if !keyboardVisible {
                PortalTabBar(selection: $router.tab)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task { await vm.autoLoad() }
        .onAppear {
            vm.vision = vision
            router.onPhoto = { image in vm.startPhoto(image) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .tint(Theme.cyan)
        .environmentObject(vm)
        .environmentObject(router)
        .environmentObject(vision)
        .fullScreenCover(isPresented: $router.showCamera) {
            CameraView().environmentObject(router)
        }
        .sheet(isPresented: $router.showAnalysis) {
            AnalysisView().environmentObject(router).environmentObject(vm)
        }
        .sheet(isPresented: $router.showModelSheet) {
            ModelSheet().environmentObject(vm).environmentObject(vision)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch router.tab {
        case .home: HomeView()
        case .discover: DiscoverView()
        }
    }
}
