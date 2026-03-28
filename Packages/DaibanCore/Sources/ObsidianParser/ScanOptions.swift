import Foundation

public enum DailyNoteDateTarget: String, Sendable, CaseIterable {
    case dueDate = "Due Date"
    case scheduledDate = "Scheduled Date"
}

public struct ScanOptions: Sendable {
    /// When set, tasks in daily notes without the corresponding date field
    /// will inherit the date from the daily note filename.
    public let dailyNoteDateTarget: DailyNoteDateTarget?

    public static let `default` = ScanOptions(dailyNoteDateTarget: nil)

    public init(dailyNoteDateTarget: DailyNoteDateTarget?) {
        self.dailyNoteDateTarget = dailyNoteDateTarget
    }
}
