import Foundation
import ObsidianParser
#if os(macOS)
import AppKit
#endif

@Observable
final class VaultStore {
    private(set) var tasks: [ObsidianTask] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var vaultURL: URL?

    private let scanner = VaultScanner()
    private let writer = TaskWriter()

    private static let bookmarkKey = "vaultBookmarkData"

    var incompleteTasks: [ObsidianTask] {
        tasks.filter { !$0.status.isComplete }
    }

    var completedTasks: [ObsidianTask] {
        tasks.filter { $0.status.isComplete }
    }

    var hasVault: Bool {
        vaultURL != nil
    }

    init() {
        restoreBookmark()
    }

    func selectVault() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian vault folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveBookmark(for: url)
        vaultURL = url
        reload()
        #endif
    }

    func reload() {
        guard let url = vaultURL else { return }
        isLoading = true
        error = nil

        Task.detached { [scanner] in
            do {
                let scanned = try scanner.scanVault(at: url)
                await MainActor.run { [self] in
                    self.tasks = scanned
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { [self] in
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func toggleCompletion(_ task: ObsidianTask) {
        guard let vaultURL else { return }

        let fileURL = vaultURL.appendingPathComponent(task.filePath)
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let newLine = writer.toggleCompletion(task)
            let newContent = writer.replaceLine(in: content, at: task.lineNumber, with: newLine)
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func disconnectVault() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        vaultURL = nil
        tasks = []
    }

    // MARK: - Bookmark persistence

    private func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        } catch {
            self.error = "Failed to save bookmark: \(error.localizedDescription)"
        }
    }

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard url.startAccessingSecurityScopedResource() else { return }
            vaultURL = url
            if isStale {
                saveBookmark(for: url)
            }
            reload()
        } catch {
            self.error = "Failed to restore vault access: \(error.localizedDescription)"
        }
    }
}
