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

        let extractor: FilenameDateExtractor?
        if options.useFilenameDateAsScheduled {
            extractor = FilenameDateExtractor(
                additionalFormat: options.filenameDateAdditionalFormat,
                folders: options.filenameDateFolders
            )
        } else {
            extractor = nil
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

            if let extractor,
               let noteDate = extractor.dateFromFilePath(relativePath) {
                fileTasks = fileTasks.map { task in
                    applyFilenameDateAsScheduled(task, date: noteDate)
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

    /// Applies the filename date as scheduled date only if the task is "undated"
    /// (has no due, scheduled, or start date).
    private func applyFilenameDateAsScheduled(_ task: ObsidianTask, date: Date) -> ObsidianTask {
        guard task.dueDate == nil, task.scheduledDate == nil, task.startDate == nil else {
            return task
        }
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
