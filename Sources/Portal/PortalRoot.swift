import SwiftUI

struct PortalRoot: View {
    @StateObject private var vm = AgentViewModel()
    @StateObject private var router = PortalRouter()

    var body: some View {
        TabView(selection: $router.tab) {
            ExploreView()
                .tabItem { Label("Explore", systemImage: "viewfinder") }
                .tag(PortalRouter.Tab.explore)
            AskView()
                .tabItem { Label("Ask", systemImage: "bubble.left.and.bubble.right") }
                .tag(PortalRouter.Tab.ask)
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkle.magnifyingglass") }
                .tag(PortalRouter.Tab.discover)
            MemoryView()
                .tabItem { Label("Memory", systemImage: "brain") }
                .tag(PortalRouter.Tab.memory)
        }
        .tint(Theme.cyan)
        .environmentObject(vm)
        .environmentObject(router)
        .fullScreenCover(isPresented: $router.showCamera) {
            CameraView().environmentObject(router)
        }
        .sheet(isPresented: $router.showAnalysis) {
            AnalysisView().environmentObject(router).environmentObject(vm)
        }
        .sheet(isPresented: $router.showModelSheet) {
            ModelSheet().environmentObject(vm)
        }
        .preferredColorScheme(.dark)
    }
}
