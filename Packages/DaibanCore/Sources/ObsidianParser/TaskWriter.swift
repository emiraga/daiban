import Foundation

public struct TaskWriter: Sendable {
    private static let doneDateFieldPattern = #/\s*✅\s*\d{4}-\d{2}-\d{2}/#

    public init() {}

    /// Toggles task completion and returns the modified line.
    /// When completing: sets status to [x] and appends done date.
    /// When uncompleting: sets status to [ ] and removes done date.
    public func toggleCompletion(_ task: ObsidianTask) -> String {
        var line = task.rawLine

        if task.status.isComplete {
            // Uncomplete: change [x] or [-] back to [ ]
            line = line.replacingOccurrences(
                of: "- [\(task.status.marker)] ",
                with: "- [ ] "
            )
            // Remove done date
            line = line.replacing(Self.doneDateFieldPattern, with: "")
        } else {
            // Complete: change [ ] to [x]
            line = line.replacingOccurrences(
                of: "- [\(task.status.marker)] ",
                with: "- [x] "
            )
            // Append done date
            let today = Self.formatDate(Date())
            line += " ✅ \(today)"
        }

        return line
    }

    /// Replaces a single line in a file's content and returns the updated content.
    public func replaceLine(in fileContent: String, at lineNumber: Int, with newLine: String) -> String {
        var lines = fileContent.components(separatedBy: "\n")
        guard lineNumber >= 0, lineNumber < lines.count else { return fileContent }
        lines[lineNumber] = newLine
        return lines.joined(separator: "\n")
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }
}
