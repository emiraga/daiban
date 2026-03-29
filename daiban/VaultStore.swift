import Foundation
import ObsidianParser

enum ThemePreference: String, CaseIterable {
    case system = "Use System Theme"
    case light = "Always Use Light Theme"
    case dark = "Always Use Dark Theme"
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

        Task.detached { [scanner] in
            do {
                let scanned = try scanner.scanVault(at: url, options: options)
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
