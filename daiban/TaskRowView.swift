import SwiftUI
import ObsidianParser

struct TaskRowView: View {
    @Environment(\.obsidianVaultName) private var vaultName
    let task: ObsidianTask
    var readOnly: Bool = false
    var isPending: Bool = false
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !readOnly || task.status.isComplete || isPending {
                Button(action: onToggle) {
                    Image(systemName: checkboxIcon)
                        .foregroundStyle(checkboxColor)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(readOnly)
            }

            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(task.description)
                    .strikethrough(task.status.isComplete)
                    .foregroundStyle(task.status.isComplete ? .secondary : .primary)

                HStack(spacing: 12) {
                    if task.priority != .normal {
                        Text(task.priority.label)
                            .font(.caption)
                            .foregroundStyle(task.priority.color)
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
            let encoded = task.filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? task.filePath
            let encodedVault = vaultName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? vaultName
            Link(destination: URL(string: "obsidian://open?vault=\(encodedVault)&file=\(encoded)")!) {
                Text(task.filePath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            #endif
        }
        .padding(.vertical, 4)
    }

    private var checkboxIcon: String {
        if isPending {
            return "clock.circle.fill"
        }
        return task.status.isComplete ? "checkmark.circle.fill" : "circle"
    }

    private var checkboxColor: Color {
        if isPending {
            return .orange
        }
        return task.status.isComplete ? .green : .secondary
    }
}

private extension TaskPriority {
    var label: String {
        switch self {
        case .highest: "Highest"
        case .high: "High"
        case .medium: "Medium"
        case .normal: "Normal"
        case .low: "Low"
        case .lowest: "Lowest"
        }
    }

    var color: Color {
        switch self {
        case .highest, .high: .red
        case .medium: .orange
        case .normal: .secondary
        case .low, .lowest: .blue
        }
    }
}
