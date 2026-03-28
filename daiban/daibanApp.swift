import SwiftUI

@main
struct DaibanApp: App {
    @State private var store = VaultStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        #if os(macOS)
        Settings {
            SettingsView(store: store)
        }
        #endif
    }
}
