import SwiftUI
import ObsidianParser

struct TaskRowView: View {
    let task: ObsidianTask
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.status.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.status.isComplete ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.description)
                    .strikethrough(task.status.isComplete)
                    .foregroundStyle(task.status.isComplete ? .secondary : .primary)

                HStack(spacing: 12) {
                    if let priority = task.priority {
                        Text(priority.label)
                            .font(.caption)
                            .foregroundStyle(priority.color)
                    }

                    if let due = task.dueDate {
                        Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(due < Date() && !task.status.isComplete ? .red : .secondary)
                    }

                    if let scheduled = task.scheduledDate {
                        Label(scheduled.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let recurrence = task.recurrence {
                        Label(recurrence.rule, systemImage: "repeat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(task.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            #if os(macOS)
            Text(task.filePath)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            #endif
        }
        .padding(.vertical, 4)
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

    var color: Color {
        switch self {
        case .highest, .high: .red
        case .medium: .orange
        case .low, .lowest: .blue
        }
    }
}
