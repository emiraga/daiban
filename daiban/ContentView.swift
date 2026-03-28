import SwiftUI
import UniformTypeIdentifiers
import ObsidianParser

struct ContentView: View {
    @Bindable var store: VaultStore
    @State private var searchText = ""
    @AppStorage("showCompleted") private var showCompleted = false
    @AppStorage("selectedGrouping") private var selectedGrouping = TaskGrouping.file
    @State private var showingFolderPicker = false
    @State private var showingSettings = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum TaskGrouping: String, CaseIterable {
        case file = "File"
        case dueDate = "Due Date"
        case scheduledDate = "Scheduled Date"
        case priority = "Priority"
    }

    var filteredTasks: [ObsidianTask] {
        let base = showCompleted ? store.tasks : store.incompleteTasks
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter {
            $0.description.lowercased().contains(query)
            || $0.filePath.lowercased().contains(query)
            || $0.tags.contains(where: { $0.lowercased().contains(query) })
        }
    }

    var groupedTasks: [(String, [ObsidianTask])] {
        let tasks = filteredTasks
        switch selectedGrouping {
        case .file:
            return Dictionary(grouping: tasks, by: \.filePath)
                .sorted { $0.key < $1.key }
        case .dueDate:
            return groupByDate(tasks, keyPath: \.dueDate, noDateLabel: "No due date")
        case .scheduledDate:
            return groupByDate(tasks, keyPath: \.scheduledDate, noDateLabel: "No scheduled date")
        case .priority:
            return Dictionary(grouping: tasks) { task -> String in
                task.priority?.label ?? "No priority"
            }
            .sorted { lhs, rhs in
                let order = ["Highest", "High", "Medium", "Low", "Lowest", "No priority"]
                return (order.firstIndex(of: lhs.key) ?? 99) < (order.firstIndex(of: rhs.key) ?? 99)
            }
        }
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        Group {
            if store.hasVault {
                connectedView
            } else {
                welcomeView
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            onCompletion: handleFolderSelection
        )
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(store: store)
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        #endif
    }

    @ViewBuilder
    private var connectedView: some View {
        if isCompact {
            compactView
        } else {
            regularView
        }
    }

    // MARK: - Compact layout (iPhone)

    private var compactView: some View {
        NavigationStack {
            taskList
                .navigationTitle("Daiban")
                .searchable(text: $searchText, prompt: "Filter tasks")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Section("Show") {
                                Button {
                                    showCompleted = false
                                } label: {
                                    Label("Incomplete (\(store.incompleteTasks.count))", systemImage: showCompleted ? "circle" : "checkmark.circle")
                                }
                                Button {
                                    showCompleted = true
                                } label: {
                                    Label("All (\(store.tasks.count))", systemImage: showCompleted ? "checkmark.circle" : "circle")
                                }
                            }

                            Section("Group By") {
                                Picker("Group By", selection: $selectedGrouping) {
                                    ForEach(TaskGrouping.allCases, id: \.self) { grouping in
                                        Text(grouping.rawValue).tag(grouping)
                                    }
                                }
                            }
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }

                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            Button("Reload", systemImage: "arrow.clockwise") {
                                store.reload()
                            }
                            Button("Change Vault", systemImage: "folder") {
                                showingFolderPicker = true
                            }
                            Button("Settings", systemImage: "gear") {
                                showingSettings = true
                            }
                            Button("Disconnect Vault", systemImage: "xmark.circle", role: .destructive) {
                                store.disconnectVault()
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
        }
    }

    // MARK: - Regular layout (macOS / iPad)

    private var regularView: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            taskList
        }
        .searchable(text: $searchText, prompt: "Filter tasks")
    }

    private var sidebar: some View {
        List {
            Section("View") {
                Label("Incomplete (\(store.incompleteTasks.count))", systemImage: "circle")
                    .onTapGesture { showCompleted = false }
                    .foregroundStyle(!showCompleted ? .primary : .secondary)

                Label("All (\(store.tasks.count))", systemImage: "list.bullet")
                    .onTapGesture { showCompleted = true }
                    .foregroundStyle(showCompleted ? .primary : .secondary)
            }

            Section("Group By") {
                Picker("Grouping", selection: $selectedGrouping) {
                    ForEach(TaskGrouping.allCases, id: \.self) { grouping in
                        Text(grouping.rawValue).tag(grouping)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Button("Reload", systemImage: "arrow.clockwise") {
                    store.reload()
                }
                Button("Change Vault", systemImage: "folder") {
                    showingFolderPicker = true
                }
                #if os(iOS)
                Button("Settings", systemImage: "gear") {
                    showingSettings = true
                }
                #endif
                Button("Disconnect Vault", systemImage: "xmark.circle", role: .destructive) {
                    store.disconnectVault()
                }
            }
        }
        .navigationTitle("Daiban")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        #endif
    }

    // MARK: - Shared views

    private var taskList: some View {
        Group {
            if store.isLoading {
                ProgressView("Scanning vault...")
            } else if let error = store.error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if filteredTasks.isEmpty {
                ContentUnavailableView("No Tasks", systemImage: "checkmark.circle", description: Text("No tasks found"))
            } else {
                List {
                    ForEach(groupedTasks, id: \.0) { group, tasks in
                        Section(group) {
                            ForEach(tasks) { task in
                                TaskRowView(task: task) {
                                    store.toggleCompletion(task)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupByDate(_ tasks: [ObsidianTask], keyPath: KeyPath<ObsidianTask, Date?>, noDateLabel: String) -> [(String, [ObsidianTask])] {
        Dictionary(grouping: tasks) { task -> String in
            if let date = task[keyPath: keyPath] {
                return date.formatted(date: .abbreviated, time: .omitted)
            }
            return noDateLabel
        }
        .sorted { lhs, rhs in
            if lhs.key == noDateLabel { return false }
            if rhs.key == noDateLabel { return true }
            return lhs.key < rhs.key
        }
    }

    private var welcomeView: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Welcome to Daiban", systemImage: "checkmark.circle")
            } description: {
                Text("Select your Obsidian vault to get started")
            } actions: {
                Button("Open Vault") {
                    showingFolderPicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Daiban")
        }
    }

    private func handleFolderSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            store.setVault(url: url)
        case .failure(let error):
            store.error = error.localizedDescription
        }
    }
}

private extension TaskPriority {
    var label: String {
        switch self {
        case .highest: "Highest"
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .lowest: "Lowest"
        }
    }
}

#Preview {
    ContentView(store: VaultStore())
}
