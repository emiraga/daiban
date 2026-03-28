import Foundation

public struct TaskParser: Sendable {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let taskPattern = #/^(\s*)- \[(.)\] (.+)$/#
    private static let dueDatePattern = #/📅\s*(\d{4}-\d{2}-\d{2})/#
    private static let scheduledDatePattern = #/⏳\s*(\d{4}-\d{2}-\d{2})/#
    private static let startDatePattern = #/🛫\s*(\d{4}-\d{2}-\d{2})/#
    private static let createdDatePattern = #/➕\s*(\d{4}-\d{2}-\d{2})/#
    private static let doneDatePattern = #/✅\s*(\d{4}-\d{2}-\d{2})/#
    private static let recurrencePattern = #/🔁\s*(.+?)(?:\s*[📅⏳🛫➕✅⏫🔼🔽⬇🔺]|$)/#
    private static let tagPattern = #/#([\w\/-]+)/#
    private static let dateFieldPattern = #/[📅⏳🛫➕✅]\s*\d{4}-\d{2}-\d{2}/#
    private static let recurrenceFieldPattern = #/🔁\s*[^📅⏳🛫➕✅⏫🔼🔽⬇🔺]*/#
    private static let tagFieldPattern = #/#[\w\/-]+/#

    public init() {}

    public func parseLine(_ line: String, filePath: String, lineNumber: Int) -> ObsidianTask? {
        guard let match = line.wholeMatch(of: TaskParser.taskPattern) else {
            return nil
        }

        let indentation = match.1.count
        let statusChar = match.2
        let body = String(match.3)

        let status = TaskStatus(marker: statusChar.first ?? " ")
        let priority = Self.parsePriority(body)
        let dueDate = Self.parseDate(body, pattern: Self.dueDatePattern)
        let scheduledDate = Self.parseDate(body, pattern: Self.scheduledDatePattern)
        let startDate = Self.parseDate(body, pattern: Self.startDatePattern)
        let createdDate = Self.parseDate(body, pattern: Self.createdDatePattern)
        let doneDate = Self.parseDate(body, pattern: Self.doneDatePattern)
        let recurrence = Self.parseRecurrence(body)
        let tags = Self.parseTags(body)
        let description = Self.extractDescription(body)

        return ObsidianTask(
            description: description,
            status: status,
            priority: priority,
            dueDate: dueDate,
            scheduledDate: scheduledDate,
            startDate: startDate,
            createdDate: createdDate,
            doneDate: doneDate,
            recurrence: recurrence,
            tags: tags,
            filePath: filePath,
            lineNumber: lineNumber,
            rawLine: line,
            indentation: indentation
        )
    }

    public func parseFile(content: String, filePath: String) -> [ObsidianTask] {
        content.components(separatedBy: .newlines).enumerated().compactMap { index, line in
            parseLine(line, filePath: filePath, lineNumber: index)
        }
    }

    // MARK: - Private

    private static func parsePriority(_ body: String) -> TaskPriority? {
        if body.contains("🔺") { return .highest }
        if body.contains("⏫") { return .high }
        if body.contains("🔼") { return .medium }
        if body.contains("🔽") { return .low }
        if body.contains("⬇️") || body.contains("⬇") { return .lowest }
        return nil
    }

    private static func parseDate(_ body: String, pattern: some RegexComponent<(Substring, Substring)>) -> Date? {
        guard let match = body.firstMatch(of: pattern) else { return nil }
        return dateFormatter.date(from: String(match.1))
    }

    private static func parseRecurrence(_ body: String) -> RecurrenceRule? {
        guard let match = body.firstMatch(of: recurrencePattern) else { return nil }
        let rule = String(match.1).trimmingCharacters(in: .whitespaces)
        return rule.isEmpty ? nil : RecurrenceRule(rule: rule)
    }

    private static func parseTags(_ body: String) -> [String] {
        body.matches(of: tagPattern).map { String($0.1) }
    }

    private static func extractDescription(_ body: String) -> String {
        var desc = body

        // Remove priority emojis
        for emoji in ["🔺", "⏫", "🔼", "🔽", "⬇️", "⬇"] {
            desc = desc.replacingOccurrences(of: emoji, with: "")
        }

        // Remove date fields (emoji + date)
        desc = desc.replacing(dateFieldPattern, with: "")

        // Remove recurrence
        desc = desc.replacing(recurrenceFieldPattern, with: "")

        // Remove tags
        desc = desc.replacing(tagFieldPattern, with: "")

        // Clean up whitespace
        desc = desc.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return desc
    }
}
