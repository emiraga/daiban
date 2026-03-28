import Foundation

public struct VaultScanner: Sendable {
    private let parser = TaskParser()

    public init() {}

    /// Scans all markdown files in the vault directory and returns parsed tasks.
    public func scanVault(at url: URL) throws -> [ObsidianTask] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw VaultScanError.cannotEnumerateDirectory(url.path)
        }

        var tasks: [ObsidianTask] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: url.path + "/",
                with: ""
            )
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let fileTasks = parser.parseFile(content: content, filePath: relativePath)
            tasks.append(contentsOf: fileTasks)
        }

        return tasks
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
