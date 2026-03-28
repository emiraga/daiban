import SwiftUI
import ObsidianParser

struct ContentView: View {
    @Bindable var store: VaultStore
    @State private var searchText = ""
    @AppStorage("showCompleted") private var showCompleted = false
    @AppStorage("selectedGrouping") private var selectedGrouping = TaskGrouping.file

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

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if store.hasVault {
                taskList
            } else {
                welcomeView
            }
        }
        .searchable(text: $searchText, prompt: "Filter tasks")
    }

    private var sidebar: some View {
        List {
            if store.hasVault {
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
                        store.selectVault()
                    }
                    Button("Disconnect Vault", systemImage: "xmark.circle", role: .destructive) {
                        store.disconnectVault()
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }

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
        .navigationTitle("Daiban")
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
        ContentUnavailableView {
            Label("Welcome to Daiban", systemImage: "checkmark.circle")
        } description: {
            Text("Select your Obsidian vault to get started")
        } actions: {
            Button("Open Vault") {
                store.selectVault()
            }
            .buttonStyle(.borderedProminent)
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
