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
                .environment(\.obsidianVaultName, store.vaultName)
                .preferredColorScheme(preferredColorScheme)
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    store.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}
