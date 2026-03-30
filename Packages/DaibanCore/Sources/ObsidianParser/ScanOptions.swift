import Foundation

public struct ScanOptions: Sendable {
    /// When true, undated tasks (no due, scheduled, or start date) will have
    /// their scheduled date set from the filename if a date can be extracted.
    public let useFilenameDateAsScheduled: Bool

    /// An additional Moment.js date format to try when extracting dates from filenames.
    public let filenameDateAdditionalFormat: String?

    /// Folders to restrict filename date extraction to. Empty means all folders.
    public let filenameDateFolders: [String]

    public static let `default` = ScanOptions(useFilenameDateAsScheduled: false)

    public init(
        useFilenameDateAsScheduled: Bool,
        filenameDateAdditionalFormat: String? = nil,
        filenameDateFolders: [String] = []
    ) {
        self.useFilenameDateAsScheduled = useFilenameDateAsScheduled
        self.filenameDateAdditionalFormat = filenameDateAdditionalFormat
        self.filenameDateFolders = filenameDateFolders
    }
}
