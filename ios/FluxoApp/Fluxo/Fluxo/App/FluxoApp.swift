import SwiftUI

@main
struct FluxoApp: App {
    // Dependencias container (services, router, camera facade).
    @StateObject private var container = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .task {
                    // Restore session once when app starts.
                    await container.startIfNeeded()
                }
        }
    }
}
