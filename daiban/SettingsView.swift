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

            Section("Post-Write Action") {
                Picker("Action", selection: $store.postWriteAction) {
                    ForEach(PostWriteAction.allCases, id: \.self) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
                .pickerStyle(.menu)

                switch store.postWriteAction {
                case .none:
                    Text("No action will be performed after writing changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .openURL:
                    TextField("URL Scheme", text: $store.postWriteURLScheme, prompt: Text("obsidian://"))
                    Text("Opens the specified URL scheme after writing changes. Defaults to Obsidian.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .runShortcut:
                    TextField("Shortcut Name", text: $store.postWriteShortcutName, prompt: Text("My Shortcut"))
                    Text("Runs the specified Shortcut after writing changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Completed Tasks") {
                Picker("Retention", selection: $store.completedTaskRetention) {
                    ForEach(CompletedTaskRetention.allCases, id: \.self) { retention in
                        Text(retention.rawValue).tag(retention)
                    }
                }
                .pickerStyle(.menu)

                switch store.completedTaskRetention {
                case .keepAll:
                    Text("All completed tasks are shown regardless of age.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .ignoreOlderThanWeek:
                    Text("Completed tasks older than 1 week are hidden. Tasks without any dates are kept.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .ignoreOlderThanWeekAndUndated:
                    Text("Completed tasks older than 1 week and those without any dates are hidden.")
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
