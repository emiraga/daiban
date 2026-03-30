import SwiftUI
import ObsidianParser

struct RecentUpdatesView: View {
    @Bindable var store: VaultStore
    @State private var undoError: String?

    var body: some View {
        Group {
            if store.recentUpdates.isEmpty {
                ContentUnavailableView("No Recent Updates", systemImage: "clock", description: Text("Changes made by the app will appear here"))
            } else {
                List {
                    ForEach(store.recentUpdates) { update in
                        RecentUpdateRow(update: update) {
                            do {
                                try store.undoRecentUpdate(update)
                                undoError = nil
                            } catch {
                                undoError = error.localizedDescription
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        if let undoError {
                            Text(undoError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        HStack {
                            Button("Clear All", role: .destructive) {
                                store.clearRecentUpdates()
                            }
                            Spacer()
                        }
                        .padding()
                    }
                    .background(.bar)
                }
            }
        }
        .navigationTitle("Recent Updates")
        #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
        #endif
    }
}

private struct RecentUpdateRow: View {
    let update: RecentUpdate
    let onUndo: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(update.task.description)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(update.task.filePath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(statusChangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(update.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                onUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help("Undo this change")
        }
        .padding(.vertical, 4)
    }

    private var statusChangeLabel: String {
        // The original task status is pre-toggle, so the change was the opposite
        if update.task.status.isComplete {
            return "→ incomplete"
        } else {
            return "→ done"
        }
    }
}
