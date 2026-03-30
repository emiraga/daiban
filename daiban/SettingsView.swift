import SwiftUI

struct SettingsView: View {
    @Bindable var store: VaultStore

    var body: some View {
        Form {
            Section("Dates from file names") {
                Toggle("Use filename as Scheduled date for undated tasks", isOn: $store.useDailyNoteDate)
                Text("If this option is enabled, any undated tasks will be given a default Scheduled date extracted from their file name.\nBy default, matches both `YYYY-MM-DD` and `YYYYMMDD` date formats.\nUndated tasks have none of Due, Scheduled and Start dates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.useDailyNoteDate {
                    TextField(
                        "Additional date format",
                        text: $store.filenameDateAdditionalFormat,
                        prompt: Text("e.g. MMM DD YYYY"))
                    Text("An additional date format (Moment.js syntax) to recognize when extracting dates from file names.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Folders",
                        text: $store.filenameDateFolders,
                        prompt: Text("Leave empty for all folders"))
                    Text("Leave empty to use filename dates everywhere, or enter a comma-separated list of folders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Obsidian") {
                TextField(
                    "Vault name", text: $store.vaultNameOverride,
                    prompt: Text(store.vaultURL?.lastPathComponent ?? "Vault name"))
                Text("Used for obsidian://open?vault=VAULT_NAME&file=FILE_NAME")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    TextField(
                        "URL Scheme", text: $store.postWriteURLScheme, prompt: Text("obsidian://"))
                    Text(
                        "Opens the specified URL scheme after writing changes. Defaults to Obsidian."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                case .runShortcut:
                    TextField(
                        "Shortcut Name", text: $store.postWriteShortcutName,
                        prompt: Text("My Shortcut"))
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
                    Text(
                        "Completed tasks older than 1 week are hidden. Tasks without any dates are kept."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                case .ignoreOlderThanWeekAndUndated:
                    Text(
                        "Completed tasks older than 1 week and those without any dates are hidden."
                    )
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
    }
}
