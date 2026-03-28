import Foundation

public enum TaskStatus: Equatable, Sendable {
    case todo
    case done
    case cancelled
    case inProgress
    case custom(Character)

    public init(marker: Character) {
        switch marker {
        case " ": self = .todo
        case "x", "X": self = .done
        case "-": self = .cancelled
        case "/": self = .inProgress
        default: self = .custom(marker)
        }
    }

    public var marker: Character {
        switch self {
        case .todo: return " "
        case .done: return "x"
        case .cancelled: return "-"
        case .inProgress: return "/"
        case .custom(let c): return c
        }
    }

    public var isComplete: Bool {
        switch self {
        case .done, .cancelled: return true
        default: return false
        }
    }
}

public enum TaskPriority: Int, Comparable, Sendable {
    case highest = 0
    case high = 1
    case medium = 2
    case normal = 3
    case low = 4
    case lowest = 5

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct RecurrenceRule: Equatable, Sendable {
    public let rule: String

    public init(rule: String) {
        self.rule = rule
    }
}

public struct ObsidianTask: Equatable, Sendable, Identifiable {
    public let id: String
    public let description: String
    public var status: TaskStatus
    public let priority: TaskPriority
    public let dueDate: Date?
    public let scheduledDate: Date?
    public let startDate: Date?
    public let createdDate: Date?
    public let doneDate: Date?
    public let recurrence: RecurrenceRule?
    public let tags: [String]

    /// The file this task was found in, relative to the vault root
    public let filePath: String
    /// Zero-based line index within the file
    public let lineNumber: Int
    /// The original raw line text, for write-back
    public let rawLine: String
    /// Indentation level (number of leading whitespace characters)
    public let indentation: Int

    public init(
        description: String,
        status: TaskStatus,
        priority: TaskPriority = .normal,
        dueDate: Date? = nil,
        scheduledDate: Date? = nil,
        startDate: Date? = nil,
        createdDate: Date? = nil,
        doneDate: Date? = nil,
        recurrence: RecurrenceRule? = nil,
        tags: [String] = [],
        filePath: String,
        lineNumber: Int,
        rawLine: String,
        indentation: Int = 0
    ) {
        self.id = "\(filePath):\(lineNumber)"
        self.description = description
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.scheduledDate = scheduledDate
        self.startDate = startDate
        self.createdDate = createdDate
        self.doneDate = doneDate
        self.recurrence = recurrence
        self.tags = tags
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.rawLine = rawLine
        self.indentation = indentation
    }
}
