import SwiftUI
import ObsidianParser

struct SettingsView: View {
    @Bindable var store: VaultStore

    var body: some View {
        Form {
            Section("Daily Notes") {
                Toggle("Use date from Daily Note filename", isOn: $store.useDailyNoteDate)

                if store.useDailyNoteDate {
                    Picker("Apply as", selection: $store.dailyNoteDateTarget) {
                        ForEach(DailyNoteDateTarget.allCases, id: \.self) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .pickerStyle(.menu)

                    if let config = store.dailyNotesConfig {
                        LabeledContent("Detected folder", value: config.folder.isEmpty ? "/" : config.folder)
                        LabeledContent("Detected format", value: config.dateFormat)
                    } else if store.hasVault {
                        Label("No daily notes plugin config found in vault", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Obsidian") {
                TextField("Vault name", text: $store.vaultNameOverride, prompt: Text(store.vaultURL?.lastPathComponent ?? "Vault name"))
            }

            Section("Updates") {
                Picker("Write Mode", selection: $store.writeMode) {
                    ForEach(WriteMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                switch store.writeMode {
                case .disabled:
                    Text("Task changes will not be written to vault files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .immediate:
                    Text("Task changes are written to vault files immediately.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .batched:
                    Text("Task changes are queued and written when you apply them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $store.themePreference) {
                    ForEach(ThemePreference.allCases, id: \.self) { preference in
                        Text(preference.rawValue).tag(preference)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 200)
        #endif
    }
}
