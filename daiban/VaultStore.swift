import Foundation
import ObsidianParser

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

struct PendingUpdate: Identifiable, Equatable {
    let id = UUID()
    let task: ObsidianTask
    /// The new line content after toggling
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
    private(set) var vaultURL: URL?
    private(set) var dailyNotesConfig: DailyNotesConfig?

    var useDailyNoteDate: Bool {
        didSet {
            UserDefaults.standard.set(useDailyNoteDate, forKey: "useDailyNoteDate")
            reload()
        }
    }

    var dailyNoteDateTarget: DailyNoteDateTarget {
        didSet {
            UserDefaults.standard.set(dailyNoteDateTarget.rawValue, forKey: "dailyNoteDateTarget")
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

    private(set) var pendingUpdates: [PendingUpdate] = []

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
        let savedTarget = UserDefaults.standard.string(forKey: "dailyNoteDateTarget")
        self.dailyNoteDateTarget = savedTarget.flatMap(DailyNoteDateTarget.init(rawValue:)) ?? .dueDate
        let savedTheme = UserDefaults.standard.string(forKey: "themePreference")
        self.themePreference = savedTheme.flatMap(ThemePreference.init(rawValue:)) ?? .system
        let savedWriteMode = UserDefaults.standard.string(forKey: "writeMode")
        self.writeMode = savedWriteMode.flatMap(WriteMode.init(rawValue:)) ?? .disabled
        let savedRetention = UserDefaults.standard.string(forKey: "completedTaskRetention")
        self.completedTaskRetention = savedRetention.flatMap(CompletedTaskRetention.init(rawValue:)) ?? .ignoreOlderThanWeek
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
        refreshDailyNotesConfig()
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
                let filtered: [ObsidianTask]
                switch retention {
                case .keepAll:
                    filtered = scanned
                case .ignoreOlderThanWeek:
                    let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
                    filtered = scanned.filter { task in
                        guard task.status.isComplete else { return true }
                        let referenceDate = task.doneDate
                            ?? [task.createdDate, task.scheduledDate, task.dueDate].compactMap { $0 }.max()
                        guard let referenceDate else { return true }
                        return referenceDate >= oneWeekAgo
                    }
                case .ignoreOlderThanWeekAndUndated:
                    let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
                    filtered = scanned.filter { task in
                        guard task.status.isComplete else { return true }
                        let referenceDate = task.doneDate
                            ?? [task.createdDate, task.scheduledDate, task.dueDate].compactMap { $0 }.max()
                        guard let referenceDate else { return false }
                        return referenceDate >= oneWeekAgo
                    }
                }
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
            // Apply updates in reverse line order so line numbers stay valid
            let sorted = updates.sorted { $0.task.lineNumber > $1.task.lineNumber }
            for update in sorted {
                content = writer.replaceLine(in: content, at: update.task.lineNumber, with: update.newLine)
            }
            try coordinatedWrite(content, to: fileURL)
        }

        pendingUpdates.removeAll()
        reload()
    }

    func discardPendingUpdates() {
        pendingUpdates.removeAll()
    }

    func discardPendingUpdate(_ update: PendingUpdate) {
        pendingUpdates.removeAll { $0.id == update.id }
    }

    private func writeToggle(_ task: ObsidianTask) {
        guard let vaultURL else { return }

        let fileURL = vaultURL.appendingPathComponent(task.filePath)
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let newLine = writer.toggleCompletion(task)
            let newContent = writer.replaceLine(in: content, at: task.lineNumber, with: newLine)
            try coordinatedWrite(newContent, to: fileURL)
            reload()
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
        dailyNotesConfig = nil
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
        ScanOptions(dailyNoteDateTarget: useDailyNoteDate ? dailyNoteDateTarget : nil)
    }

    private func refreshDailyNotesConfig() {
        guard let url = vaultURL else {
            dailyNotesConfig = nil
            return
        }
        dailyNotesConfig = scanner.loadDailyNotesConfig(vaultURL: url)
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
            refreshDailyNotesConfig()
            startWatching(url: url)
            reload()
        } catch {
            self.error = "Failed to restore vault access: \(error.localizedDescription)"
        }
    }
}
