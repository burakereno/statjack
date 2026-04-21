import SwiftUI

@main
struct StatJackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scene — everything is managed by AppDelegate via NSStatusItem
        Settings {
            EmptyView()
        }
    }
}
