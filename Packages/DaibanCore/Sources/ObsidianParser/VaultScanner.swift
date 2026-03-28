import Foundation

public struct VaultScanner: Sendable {
    private let parser = TaskParser()

    public init() {}

    /// Scans all markdown files in the vault directory and returns parsed tasks.
    public func scanVault(at url: URL, options: ScanOptions = .default) throws -> [ObsidianTask] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw VaultScanError.cannotEnumerateDirectory(url.path)
        }

        let dailyNotesConfig: DailyNotesConfig?
        if options.dailyNoteDateTarget != nil {
            dailyNotesConfig = DailyNotesConfig.load(vaultURL: url)
        } else {
            dailyNotesConfig = nil
        }

        var tasks: [ObsidianTask] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: url.path + "/",
                with: ""
            )
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            var fileTasks = parser.parseFile(content: content, filePath: relativePath)

            if let target = options.dailyNoteDateTarget,
               let config = dailyNotesConfig,
               let noteDate = config.dateFromFilePath(relativePath) {
                fileTasks = fileTasks.map { task in
                    applyDailyNoteDate(task, date: noteDate, target: target)
                }
            }

            tasks.append(contentsOf: fileTasks)
        }

        return tasks
    }

    /// Loads the daily notes config from the vault, if available.
    public func loadDailyNotesConfig(vaultURL: URL) -> DailyNotesConfig? {
        DailyNotesConfig.load(vaultURL: vaultURL)
    }

    private func applyDailyNoteDate(_ task: ObsidianTask, date: Date, target: DailyNoteDateTarget) -> ObsidianTask {
        switch target {
        case .dueDate where task.dueDate == nil:
            return ObsidianTask(
                description: task.description,
                status: task.status,
                priority: task.priority,
                dueDate: date,
                scheduledDate: task.scheduledDate,
                startDate: task.startDate,
                createdDate: task.createdDate,
                doneDate: task.doneDate,
                recurrence: task.recurrence,
                tags: task.tags,
                filePath: task.filePath,
                lineNumber: task.lineNumber,
                rawLine: task.rawLine,
                indentation: task.indentation
            )
        case .scheduledDate where task.scheduledDate == nil:
            return ObsidianTask(
                description: task.description,
                status: task.status,
                priority: task.priority,
                dueDate: task.dueDate,
                scheduledDate: date,
                startDate: task.startDate,
                createdDate: task.createdDate,
                doneDate: task.doneDate,
                recurrence: task.recurrence,
                tags: task.tags,
                filePath: task.filePath,
                lineNumber: task.lineNumber,
                rawLine: task.rawLine,
                indentation: task.indentation
            )
        default:
            return task
        }
    }
}

public enum VaultScanError: Error, LocalizedError {
    case cannotEnumerateDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .cannotEnumerateDirectory(let path):
            return "Cannot enumerate directory at \(path)"
        }
    }
}
