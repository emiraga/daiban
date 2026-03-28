import Foundation

public struct DailyNotesConfig: Equatable, Sendable {
    public let folder: String
    public let dateFormat: String

    public init(folder: String, dateFormat: String) {
        self.folder = folder
        self.dateFormat = dateFormat
    }

    /// Reads the daily notes configuration from the vault's .obsidian directory.
    /// Checks which plugin is enabled and loads from the appropriate source.
    public static func load(vaultURL: URL) -> DailyNotesConfig? {
        let obsidianDir = vaultURL.appendingPathComponent(".obsidian")

        // Check if periodic-notes community plugin is enabled
        if isCommunityPluginEnabled("periodic-notes", obsidianDir: obsidianDir),
           let config = loadPeriodicNotesConfig(obsidianDir: obsidianDir) {
            return config
        }

        // Check if core daily-notes plugin is enabled
        if isCorePluginEnabled("daily-notes", obsidianDir: obsidianDir),
           let config = loadCoreConfig(obsidianDir: obsidianDir) {
            return config
        }

        // Fallback: try loading from either config file regardless of enabled state
        if let config = loadPeriodicNotesConfig(obsidianDir: obsidianDir) {
            return config
        }
        if let config = loadCoreConfig(obsidianDir: obsidianDir) {
            return config
        }

        return nil
    }

    /// Extracts a date from a daily note file path, given this config.
    /// Returns nil if the file is not in the daily notes folder or doesn't match the format.
    public func dateFromFilePath(_ relativePath: String) -> Date? {
        let pathWithoutExtension: String
        if relativePath.hasSuffix(".md") {
            pathWithoutExtension = String(relativePath.dropLast(3))
        } else {
            pathWithoutExtension = relativePath
        }

        let expectedPrefix = folder.isEmpty ? "" : folder + "/"
        guard pathWithoutExtension.hasPrefix(expectedPrefix) else { return nil }

        let filename = String(pathWithoutExtension.dropFirst(expectedPrefix.count))

        // Don't match if there are subdirectories beyond the daily notes folder
        guard !filename.contains("/") else { return nil }

        let swiftFormat = Self.momentToSwiftDateFormat(dateFormat)
        let formatter = DateFormatter()
        formatter.dateFormat = swiftFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        return formatter.date(from: filename)
    }

    // MARK: - Plugin enabled checks

    private static func isCorePluginEnabled(_ pluginId: String, obsidianDir: URL) -> Bool {
        let migrationURL = obsidianDir.appendingPathComponent("core-plugins-migration.json")
        guard let data = try? Data(contentsOf: migrationURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] else {
            return false
        }
        return json[pluginId] == true
    }

    private static func isCommunityPluginEnabled(_ pluginId: String, obsidianDir: URL) -> Bool {
        let pluginsURL = obsidianDir.appendingPathComponent("community-plugins.json")
        guard let data = try? Data(contentsOf: pluginsURL),
              let plugins = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return false
        }
        return plugins.contains(pluginId)
    }

    // MARK: - Config loading

    private static func loadCoreConfig(obsidianDir: URL) -> DailyNotesConfig? {
        let configURL = obsidianDir.appendingPathComponent("daily-notes.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let folder = (json["folder"] as? String) ?? ""
        let format = (json["format"] as? String) ?? "YYYY-MM-DD"
        return DailyNotesConfig(folder: folder, dateFormat: format)
    }

    private static func loadPeriodicNotesConfig(obsidianDir: URL) -> DailyNotesConfig? {
        let configURL = obsidianDir
            .appendingPathComponent("plugins")
            .appendingPathComponent("periodic-notes")
            .appendingPathComponent("data.json")

        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daily = json["daily"] as? [String: Any] else {
            return nil
        }

        let folder = (daily["folder"] as? String) ?? ""
        let format = (daily["format"] as? String) ?? "YYYY-MM-DD"
        return DailyNotesConfig(folder: folder, dateFormat: format)
    }

    // MARK: - Date format conversion

    /// Converts Moment.js date format tokens to Swift DateFormatter tokens.
    /// Single-pass scan to avoid cascading replacements.
    static func momentToSwiftDateFormat(_ moment: String) -> String {
        // Ordered longest-first so greedy matching works
        let tokens: [(String, String)] = [
            ("YYYY", "yyyy"),
            ("YY",   "yy"),
            ("MMMM", "MMMM"),
            ("MMM",  "MMM"),
            ("MM",   "MM"),
            ("dddd", "EEEE"),
            ("ddd",  "EEE"),
            ("dd",   "EE"),
            ("DD",   "dd"),
            ("Do",   "d"),
            ("D",    "d"),
        ]

        var result = ""
        var index = moment.startIndex

        while index < moment.endIndex {
            var matched = false
            for (from, to) in tokens {
                if moment[index...].hasPrefix(from) {
                    result += to
                    index = moment.index(index, offsetBy: from.count)
                    matched = true
                    break
                }
            }
            if !matched {
                result.append(moment[index])
                index = moment.index(after: index)
            }
        }

        return result
    }
}
