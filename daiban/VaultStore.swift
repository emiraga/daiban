import Foundation
import ObsidianParser
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ThemePreference: String, CaseIterable {
    case system = "Use System Theme"
    case light = "Always Use Light Theme"
    case dark = "Always Use Dark Theme"
}

enum CompletedTaskRetention: String, CaseIterable {
    case keepAll = "Keep All"
    case ignoreOlderThanWeek = "Hide Older Than 1 Week"
    case ignoreOlderThanWeekAndUndated = "Hide Older Than 1 Week + Undated"
}

enum WriteMode: String, CaseIterable {
    case disabled = "Read Only"
    case immediate = "Immediate"
    case batched = "Batched"
}

enum PostWriteAction: String, CaseIterable {
    case none = "None"
    case openURL = "Open URL Scheme"
    case runShortcut = "Run Shortcut"
}

struct PendingUpdate: Identifiable, Equatable {
    let id = UUID()
    let task: ObsidianTask
    /// The new line content after toggling
    let newLine: String
    let timestamp: Date
}

struct RecentUpdate: Identifiable, Equatable {
    let id = UUID()
    let task: ObsidianTask
    /// The original line content before the change (for undo)
    let originalLine: String
    /// The new line content after the change
    let newLine: String
    let timestamp: Date
}

@Observable
final class VaultStore {
    private(set) var tasks: [ObsidianTask] = [] {
        didSet { recomputeFilteredTasks() }
    }
    private(set) var incompleteTasks: [ObsidianTask] = []
    private(set) var isLoading = false
    var error: String?
    var showSettings = false
    private(set) var vaultURL: URL?
    var useDailyNoteDate: Bool {
        didSet {
            UserDefaults.standard.set(useDailyNoteDate, forKey: "useDailyNoteDate")
            reload()
        }
    }

    var filenameDateAdditionalFormat: String {
        didSet {
            UserDefaults.standard.set(filenameDateAdditionalFormat, forKey: "filenameDateAdditionalFormat")
            reload()
        }
    }

    var filenameDateFolders: String {
        didSet {
            UserDefaults.standard.set(filenameDateFolders, forKey: "filenameDateFolders")
            reload()
        }
    }

    var themePreference: ThemePreference {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: "themePreference")
        }
    }

    var vaultNameOverride: String {
        didSet {
            UserDefaults.standard.set(vaultNameOverride, forKey: "vaultNameOverride")
        }
    }

    var writeMode: WriteMode {
        didSet {
            UserDefaults.standard.set(writeMode.rawValue, forKey: "writeMode")
        }
    }

    var completedTaskRetention: CompletedTaskRetention {
        didSet {
            UserDefaults.standard.set(completedTaskRetention.rawValue, forKey: "completedTaskRetention")
            reload()
        }
    }

    var postWriteAction: PostWriteAction {
        didSet {
            UserDefaults.standard.set(postWriteAction.rawValue, forKey: "postWriteAction")
        }
    }

    var postWriteURLScheme: String {
        didSet {
            UserDefaults.standard.set(postWriteURLScheme, forKey: "postWriteURLScheme")
        }
    }

    var postWriteShortcutName: String {
        didSet {
            UserDefaults.standard.set(postWriteShortcutName, forKey: "postWriteShortcutName")
        }
    }

    private(set) var pendingUpdates: [PendingUpdate] = []
    private(set) var recentUpdates: [RecentUpdate] = []

    private let scanner = VaultScanner()
    private let writer = TaskWriter()
    private var fileWatcher: FileWatcher?

    private static let bookmarkKey = "vaultBookmarkData"

    private func recomputeFilteredTasks() {
        incompleteTasks = tasks.filter { !$0.status.isComplete }
    }

    var hasVault: Bool {
        vaultURL != nil
    }

    var vaultName: String {
        let override = vaultNameOverride.trimmingCharacters(in: .whitespaces)
        if !override.isEmpty { return override }
        return vaultURL?.lastPathComponent ?? ""
    }

    init() {
        self.vaultNameOverride = UserDefaults.standard.string(forKey: "vaultNameOverride") ?? ""
        self.useDailyNoteDate = UserDefaults.standard.bool(forKey: "useDailyNoteDate")
        self.filenameDateAdditionalFormat = UserDefaults.standard.string(forKey: "filenameDateAdditionalFormat") ?? ""
        self.filenameDateFolders = UserDefaults.standard.string(forKey: "filenameDateFolders") ?? ""
        let savedTheme = UserDefaults.standard.string(forKey: "themePreference")
        self.themePreference = savedTheme.flatMap(ThemePreference.init(rawValue:)) ?? .system
        let savedWriteMode = UserDefaults.standard.string(forKey: "writeMode")
        self.writeMode = savedWriteMode.flatMap(WriteMode.init(rawValue:)) ?? .disabled
        let savedRetention = UserDefaults.standard.string(forKey: "completedTaskRetention")
        self.completedTaskRetention = savedRetention.flatMap(CompletedTaskRetention.init(rawValue:)) ?? .ignoreOlderThanWeek
        let savedPostWriteAction = UserDefaults.standard.string(forKey: "postWriteAction")
        self.postWriteAction = savedPostWriteAction.flatMap(PostWriteAction.init(rawValue:)) ?? .none
        self.postWriteURLScheme = UserDefaults.standard.string(forKey: "postWriteURLScheme") ?? "obsidian://"
        self.postWriteShortcutName = UserDefaults.standard.string(forKey: "postWriteShortcutName") ?? ""
        restoreBookmark()
    }

    /// Called by the view layer after the user picks a folder via .fileImporter
    func setVault(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            error = "Failed to access the selected folder"
            return
        }
        saveBookmark(for: url)
        vaultURL = url
        startWatching(url: url)
        reload()
    }

    func reload() {
        guard let url = vaultURL else { return }
        isLoading = true
        error = nil

        let options = scanOptions
        let retention = completedTaskRetention

        Task.detached { [scanner] in
            do {
                let scanned = try scanner.scanVault(at: url, options: options)
                let filtered = Self.filterTasks(scanned, retention: retention)
                await MainActor.run { [self] in
                    self.tasks = filtered
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

    func refresh() async {
        guard let url = vaultURL else { return }
        isLoading = true
        error = nil

        let options = scanOptions
        let retention = completedTaskRetention

        do {
            let scanned = try await Task.detached { [scanner] in
                try scanner.scanVault(at: url, options: options)
            }.value
            self.tasks = Self.filterTasks(scanned, retention: retention)
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }

    private nonisolated static func filterTasks(_ scanned: [ObsidianTask], retention: CompletedTaskRetention) -> [ObsidianTask] {
        switch retention {
        case .keepAll:
            return scanned
        case .ignoreOlderThanWeek:
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
            return scanned.filter { task in
                guard task.status.isComplete else { return true }
                let referenceDate = task.doneDate
                    ?? [task.createdDate, task.scheduledDate, task.dueDate].compactMap { $0 }.max()
                guard let referenceDate else { return true }
                return referenceDate >= oneWeekAgo
            }
        case .ignoreOlderThanWeekAndUndated:
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
            return scanned.filter { task in
                guard task.status.isComplete else { return true }
                let referenceDate = task.doneDate
                    ?? [task.createdDate, task.scheduledDate, task.dueDate].compactMap { $0 }.max()
                guard let referenceDate else { return false }
                return referenceDate >= oneWeekAgo
            }
        }
    }

    func toggleCompletion(_ task: ObsidianTask) {
        switch writeMode {
        case .disabled:
            return
        case .immediate:
            writeToggle(task)
        case .batched:
            let newLine = writer.toggleCompletion(task)
            // If there's already a pending update for this task, remove it (user toggled back)
            if let existingIndex = pendingUpdates.firstIndex(where: { $0.task.id == task.id }) {
                pendingUpdates.remove(at: existingIndex)
            } else {
                pendingUpdates.append(PendingUpdate(task: task, newLine: newLine, timestamp: Date()))
            }
        }
    }

    func applyPendingUpdates() throws {
        guard let vaultURL else { return }

        // Group updates by file to minimize file reads/writes
        let updatesByFile = Dictionary(grouping: pendingUpdates, by: \.task.filePath)

        for (filePath, updates) in updatesByFile {
            let fileURL = vaultURL.appendingPathComponent(filePath)
            var content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            // Apply updates in reverse line order so line numbers stay valid
            let sorted = updates.sorted { $0.task.lineNumber > $1.task.lineNumber }
            for update in sorted {
                let originalLine = lines[update.task.lineNumber]
                recordRecentUpdate(task: update.task, originalLine: originalLine, newLine: update.newLine)
                content = writer.replaceLine(in: content, at: update.task.lineNumber, with: update.newLine)
            }
            try coordinatedWrite(content, to: fileURL)
        }

        pendingUpdates.removeAll()
        reload()
        performPostWriteAction()
    }

    func performPostWriteAction() {
        switch postWriteAction {
        case .none:
            return
        case .openURL:
            let scheme = postWriteURLScheme.trimmingCharacters(in: .whitespaces)
            guard !scheme.isEmpty, let url = URL(string: scheme) else { return }
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        case .runShortcut:
            let name = postWriteShortcutName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty,
                  let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)")
            else { return }
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }

    func discardPendingUpdates() {
        pendingUpdates.removeAll()
    }

    func discardPendingUpdate(_ update: PendingUpdate) {
        pendingUpdates.removeAll { $0.id == update.id }
    }

    // MARK: - Recent Updates

    private func recordRecentUpdate(task: ObsidianTask, originalLine: String, newLine: String) {
        let update = RecentUpdate(task: task, originalLine: originalLine, newLine: newLine, timestamp: Date())
        recentUpdates.insert(update, at: 0)
    }

    func undoRecentUpdate(_ update: RecentUpdate) throws {
        guard let vaultURL else { return }

        let fileURL = vaultURL.appendingPathComponent(update.task.filePath)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let newContent = writer.replaceLine(in: content, at: update.task.lineNumber, with: update.originalLine)
        try coordinatedWrite(newContent, to: fileURL)
        recentUpdates.removeAll { $0.id == update.id }
        reload()
    }

    func clearRecentUpdates() {
        recentUpdates.removeAll()
    }

    private func writeToggle(_ task: ObsidianTask) {
        guard let vaultURL else { return }

        let fileURL = vaultURL.appendingPathComponent(task.filePath)
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let originalLine = content.components(separatedBy: "\n")[task.lineNumber]
            let newLine = writer.toggleCompletion(task)
            let newContent = writer.replaceLine(in: content, at: task.lineNumber, with: newLine)
            try coordinatedWrite(newContent, to: fileURL)
            recordRecentUpdate(task: task, originalLine: originalLine, newLine: newLine)
            reload()
            performPostWriteAction()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func coordinatedWrite(_ content: String, to fileURL: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                try content.write(to: url, atomically: false, encoding: .utf8)
            } catch {
                writeError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let writeError { throw writeError }
    }

    func disconnectVault() {
        fileWatcher?.stop()
        fileWatcher = nil
        if let url = vaultURL {
            url.stopAccessingSecurityScopedResource()
        }
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        vaultURL = nil
        tasks = []
    }

    // MARK: - Private

    private func startWatching(url: URL) {
        fileWatcher?.stop()
        let watcher = FileWatcher { [weak self] in
            self?.reload()
        }
        watcher.watch(directory: url)
        fileWatcher = watcher
    }

    private var scanOptions: ScanOptions {
        let folders = filenameDateFolders
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let additionalFormat = filenameDateAdditionalFormat.trimmingCharacters(in: .whitespaces)
        return ScanOptions(
            useFilenameDateAsScheduled: useDailyNoteDate,
            filenameDateAdditionalFormat: additionalFormat.isEmpty ? nil : additionalFormat,
            filenameDateFolders: folders
        )
    }

    // MARK: - Bookmark persistence

    private func saveBookmark(for url: URL) {
        do {
            #if os(macOS)
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            let data = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #endif
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        } catch {
            self.error = "Failed to save bookmark: \(error.localizedDescription)"
        }
    }

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        do {
            var isStale = false
            #if os(macOS)
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #else
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            #endif
            guard url.startAccessingSecurityScopedResource() else { return }
            vaultURL = url
            if isStale {
                saveBookmark(for: url)
            }
            startWatching(url: url)
            reload()
        } catch {
            self.error = "Failed to restore vault access: \(error.localizedDescription)"
        }
    }
}
