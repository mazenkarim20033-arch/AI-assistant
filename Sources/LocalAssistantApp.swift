import SwiftUI

@main
struct LocalAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            AgentView()
                .preferredColorScheme(.dark)
        }
    }
}
