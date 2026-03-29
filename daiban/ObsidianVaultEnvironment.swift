import SwiftUI

private struct ObsidianVaultNameKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var obsidianVaultName: String {
        get { self[ObsidianVaultNameKey.self] }
        set { self[ObsidianVaultNameKey.self] = newValue }
    }
}
