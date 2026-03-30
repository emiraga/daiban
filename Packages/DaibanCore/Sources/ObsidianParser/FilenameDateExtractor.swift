import Foundation

/// Extracts dates from filenames using built-in YYYY-MM-DD and YYYYMMDD patterns,
/// plus an optional additional Moment.js-style format.
/// Optionally restricts matching to specific folders.
public struct FilenameDateExtractor: Sendable {
    /// An additional Moment.js date format to try (e.g. "MMM DD YYYY").
    public let additionalFormat: String?
    /// Folders to restrict matching to. Empty means all folders.
    public let folders: [String]

    public init(additionalFormat: String? = nil, folders: [String] = []) {
        self.additionalFormat = additionalFormat
        self.folders = folders
    }

    /// Extracts a date from a file's relative path.
    /// Returns nil if no date pattern is found or the file is not in an allowed folder.
    public func dateFromFilePath(_ relativePath: String) -> Date? {
        // Check folder restriction
        if !folders.isEmpty {
            let folder = folderOfFile(relativePath)
            guard folders.contains(where: { $0 == folder }) else { return nil }
        }

        let filename = Self.filenameWithoutExtension(relativePath)
        guard !filename.isEmpty else { return nil }

        // Try built-in formats first
        if let date = Self.tryISO(filename) { return date }
        if let date = Self.tryCompact(filename) { return date }

        // Try additional format
        if let format = additionalFormat, !format.isEmpty {
            if let date = Self.tryCustomFormat(filename, momentFormat: format) { return date }
        }

        return nil
    }

    // MARK: - Folder matching

    /// Returns the folder component of a relative path, or empty string for root files.
    private func folderOfFile(_ relativePath: String) -> String {
        guard let lastSlash = relativePath.lastIndex(of: "/") else { return "" }
        return String(relativePath[..<lastSlash])
    }

    // MARK: - Filename extraction

    static func filenameWithoutExtension(_ relativePath: String) -> String {
        var path = relativePath
        if path.hasSuffix(".md") {
            path = String(path.dropLast(3))
        }
        if let lastSlash = path.lastIndex(of: "/") {
            path = String(path[path.index(after: lastSlash)...])
        }
        return path
    }

    // MARK: - Date extraction

    /// Matches YYYY-MM-DD anywhere in the filename.
    private static let isoRegex = #/(\d{4})-(\d{2})-(\d{2})/#

    /// Matches YYYYMMDD as the entire filename (no extra digits around it).
    private static let compactRegex = #/^(\d{4})(\d{2})(\d{2})$/#

    static func tryISO(_ filename: String) -> Date? {
        guard let match = filename.firstMatch(of: isoRegex) else { return nil }
        return dateFromComponents(
            year: String(match.1), month: String(match.2), day: String(match.3))
    }

    static func tryCompact(_ filename: String) -> Date? {
        guard let match = filename.firstMatch(of: compactRegex) else { return nil }
        return dateFromComponents(
            year: String(match.1), month: String(match.2), day: String(match.3))
    }

    static func tryCustomFormat(_ filename: String, momentFormat: String) -> Date? {
        let swiftFormat = DailyNotesConfig.momentToSwiftDateFormat(momentFormat)
        let formatter = DateFormatter()
        formatter.dateFormat = swiftFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: filename)
    }

    private static func dateFromComponents(year: String, month: String, day: String) -> Date? {
        guard let y = Int(year), let m = Int(month), let d = Int(day),
              m >= 1, m <= 12, d >= 1, d <= 31 else { return nil }
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.timeZone = TimeZone(identifier: "UTC")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)
    }
}
