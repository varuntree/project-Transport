import SwiftUI
import Logging

@main
struct SydneyTransitApp: App {
    init() {
        // Log app launch
        Logger.app.info("App launched")

        // Verify config loaded
        Logger.app.info("Configuration loaded", metadata: .from(["api_base_url": Config.apiBaseURL]))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
