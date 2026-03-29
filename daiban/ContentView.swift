import ObsidianParser
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: VaultStore
    @State private var searchText = ""
    @AppStorage("selectedViewMode") private var selectedViewMode = ViewMode.todo
    @AppStorage("selectedGrouping") private var selectedGrouping = TaskGrouping.file
    @State private var showingFolderPicker = false
    @State private var showingSettings = false
    @State private var showingPendingUpdates = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum ViewMode: String, CaseIterable {
        case todo = "To Do"
        case upcoming = "Upcoming"
        case incomplete = "Incomplete"
        case completed = "Completed"
        case all = "All"
    }

    enum TaskGrouping: String, CaseIterable {
        case file = "File"
        case dueDate = "Due Date"
        case scheduledDate = "Scheduled Date"
        case priority = "Priority"
    }

    private var baseTasks: [ObsidianTask] {
        switch selectedViewMode {
        case .todo:
            return store.incompleteTasks
        case .upcoming:
            let startOfTomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
            return store.incompleteTasks.filter { task in
                if let due = task.dueDate, due >= startOfTomorrow { return true }
                if let scheduled = task.scheduledDate, scheduled >= startOfTomorrow { return true }
                return false
            }
        case .incomplete:
            return store.incompleteTasks
        case .completed:
            return store.tasks.filter { $0.status.isComplete }
        case .all:
            return store.tasks
        }
    }

    var filteredTasks: [ObsidianTask] {
        let base = baseTasks
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter {
            $0.description.lowercased().contains(query)
                || $0.filePath.lowercased().contains(query)
                || $0.tags.contains(where: { $0.lowercased().contains(query) })
        }
    }

    var groupedTasks: [(String, [ObsidianTask])] {
        if selectedViewMode == .todo {
            return todoGroupedTasks
        }
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
            return groupByPriority(tasks)
        }
    }

    /// Returns tasks relevant for the To Do view: due/scheduled today or earlier, plus undated tasks
    private func todoFilteredTasks(from tasks: [ObsidianTask]) -> [ObsidianTask] {
        let endOfToday = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let dated = tasks.filter { task in
            if let due = task.dueDate, due < endOfToday { return true }
            if let scheduled = task.scheduledDate, scheduled < endOfToday { return true }
            return false
        }
        let undated = tasks.filter { task in
            task.dueDate == nil && task.scheduledDate == nil
        }
        return dated + undated
    }

    /// To Do view: tasks due/scheduled today or earlier first, then undated tasks sorted by priority
    private var todoGroupedTasks: [(String, [ObsidianTask])] {
        let tasks = filteredTasks
        let endOfToday = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)

        let datedTasks = tasks.filter { task in
            if let due = task.dueDate, due < endOfToday { return true }
            if let scheduled = task.scheduledDate, scheduled < endOfToday { return true }
            return false
        }.sorted { lhs, rhs in
            let lhsDate = earliestRelevantDate(lhs) ?? .distantFuture
            let rhsDate = earliestRelevantDate(rhs) ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.priority < rhs.priority
        }

        let undatedTasks = tasks.filter { task in
            task.dueDate == nil && task.scheduledDate == nil
        }.sorted { lhs, rhs in
            lhs.priority < rhs.priority
        }

        var groups: [(String, [ObsidianTask])] = []
        if !datedTasks.isEmpty {
            groups.append(("Due & Scheduled", datedTasks))
        }

        let priorityOrder: [(TaskPriority, String)] = [
            (.highest, "Highest Priority"),
            (.high, "High Priority"),
            (.medium, "Medium Priority"),
            (.normal, "Normal Priority"),
            (.low, "Low Priority"),
            (.lowest, "Lowest Priority"),
        ]
        for (priority, label) in priorityOrder {
            let matching = undatedTasks.filter { $0.priority == priority }
            if !matching.isEmpty {
                groups.append((label, matching))
            }
        }

        return groups
    }

    private func earliestRelevantDate(_ task: ObsidianTask) -> Date? {
        [task.dueDate, task.scheduledDate].compactMap { $0 }.min()
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
        .sheet(isPresented: $showingPendingUpdates) {
            NavigationStack {
                PendingUpdatesView(store: store)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPendingUpdates = false }
                        }
                    }
            }
        }
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
                #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .searchable(text: $searchText, prompt: "Filter tasks")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Section("View") {
                                Picker("View", selection: $selectedViewMode) {
                                    ForEach(ViewMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                            }

                            if selectedViewMode != .todo {
                                Section("Group By") {
                                    Picker("Group By", selection: $selectedGrouping) {
                                        ForEach(TaskGrouping.allCases, id: \.self) { grouping in
                                            Text(grouping.rawValue).tag(grouping)
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }

                    if store.writeMode == .batched {
                        ToolbarItem(placement: .primaryAction) {
                            pendingUpdatesButton
                        }
                    }

                    ToolbarItem(placement: .secondaryAction) {
                        Button("Reload", systemImage: "arrow.clockwise") {
                            store.reload()
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Settings", systemImage: "gear") {
                            showingSettings = true
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Change Vault", systemImage: "folder") {
                            showingFolderPicker = true
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Disconnect Vault", systemImage: "xmark.circle", role: .destructive)
                        {
                            store.disconnectVault()
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
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    let count = taskCount(for: mode)
                    Button {
                        selectedViewMode = mode
                    } label: {
                        Label("\(mode.rawValue) (\(count))", systemImage: icon(for: mode))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedViewMode == mode ? .primary : .secondary)
                }
            }

            if selectedViewMode != .todo {
                Section("Group By") {
                    Picker("Grouping", selection: $selectedGrouping) {
                        ForEach(TaskGrouping.allCases, id: \.self) { grouping in
                            Text(grouping.rawValue).tag(grouping)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }

            if store.writeMode == .batched {
                Section {
                    Button {
                        showingPendingUpdates = true
                    } label: {
                        Label("Pending Updates", systemImage: "tray.full")
                            .badge(store.pendingUpdates.count)
                    }
                }
            }

            Section {
                Button("Reload", systemImage: "arrow.clockwise") {
                    store.reload()
                }
                #if os(macOS)
                    SettingsLink {
                        Label("Settings", systemImage: "gear")
                    }
                #else
                    Button("Settings", systemImage: "gear") {
                        showingSettings = true
                    }
                #endif
                Button("Change Vault", systemImage: "folder") {
                    showingFolderPicker = true
                }
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
                ContentUnavailableView(
                    "Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if filteredTasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks", systemImage: "checkmark.circle", description: Text("No tasks found")
                )
            } else {
                List {
                    ForEach(groupedTasks, id: \.0) { group, tasks in
                        Section(group) {
                            ForEach(tasks) { task in
                                TaskRowView(
                                    task: task,
                                    readOnly: store.writeMode == .disabled,
                                    isPending: store.pendingUpdates.contains {
                                        $0.task.id == task.id
                                    }
                                ) {
                                    store.toggleCompletion(task)
                                }
                            }
                        }
                    }
                }
                .id(selectedViewMode)
            }
        }
    }

    private var pendingUpdatesButton: some View {
        Button {
            showingPendingUpdates = true
        } label: {
            Image(systemName: "tray.full")
                .overlay(alignment: .topTrailing) {
                    if !store.pendingUpdates.isEmpty {
                        Text("\(store.pendingUpdates.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.red, in: .circle)
                            .offset(x: 6, y: -6)
                    }
                }
        }
    }

    // MARK: - Helpers

    private func groupByDate(
        _ tasks: [ObsidianTask], keyPath: KeyPath<ObsidianTask, Date?>, noDateLabel: String
    ) -> [(String, [ObsidianTask])] {
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

    private func groupByPriority(_ tasks: [ObsidianTask]) -> [(String, [ObsidianTask])] {
        Dictionary(grouping: tasks) { task -> String in
            task.priority.label
        }
        .sorted { lhs, rhs in
            let order = ["Highest", "High", "Medium", "Normal", "Low", "Lowest"]
            return (order.firstIndex(of: lhs.key) ?? 99) < (order.firstIndex(of: rhs.key) ?? 99)
        }
    }

    private func taskCount(for mode: ViewMode) -> Int {
        switch mode {
        case .todo:
            return todoFilteredTasks(from: store.incompleteTasks).count
        case .upcoming:
            let startOfTomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
            return store.incompleteTasks.filter { task in
                if let due = task.dueDate, due >= startOfTomorrow { return true }
                if let scheduled = task.scheduledDate, scheduled >= startOfTomorrow { return true }
                return false
            }.count
        case .incomplete:
            return store.incompleteTasks.count
        case .completed:
            return store.tasks.filter { $0.status.isComplete }.count
        case .all:
            return store.tasks.count
        }
    }

    private func icon(for mode: ViewMode) -> String {
        switch mode {
        case .todo: "star.circle"
        case .upcoming: "calendar"
        case .incomplete: "circle"
        case .completed: "checkmark.circle"
        case .all: "list.bullet"
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

extension TaskPriority {
    fileprivate var label: String {
        switch self {
        case .highest: "Highest"
        case .high: "High"
        case .medium: "Medium"
        case .normal: "Normal"
        case .low: "Low"
        case .lowest: "Lowest"
        }
    }
}

#Preview {
    ContentView(store: VaultStore())
}
