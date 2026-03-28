import SwiftUI

@main
struct DaibanApp: App {
    @State private var store = VaultStore()

    private var preferredColorScheme: ColorScheme? {
        switch store.themePreference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(preferredColorScheme)
        }
        #if os(macOS)
        Settings {
            SettingsView(store: store)
        }
        #endif
    }
}
