import SwiftUI
import ObsidianParser

struct PendingUpdatesView: View {
    @Bindable var store: VaultStore
    @State private var applyError: String?

    var body: some View {
        Group {
            if store.pendingUpdates.isEmpty {
                ContentUnavailableView("No Pending Updates", systemImage: "tray", description: Text("Toggle tasks to queue changes"))
            } else {
                List {
                    ForEach(store.pendingUpdates) { update in
                        PendingUpdateRow(update: update) {
                            store.discardPendingUpdate(update)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        if let applyError {
                            Text(applyError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        HStack {
                            Button("Discard All", role: .destructive) {
                                store.discardPendingUpdates()
                            }
                            Spacer()
                            Button("Apply \(store.pendingUpdates.count) Update\(store.pendingUpdates.count == 1 ? "" : "s")") {
                                do {
                                    try store.applyPendingUpdates()
                                    applyError = nil
                                } catch {
                                    applyError = error.localizedDescription
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                    .background(.bar)
                }
            }
        }
        .navigationTitle("Pending Updates")
        #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
        #endif
    }
}

private struct PendingUpdateRow: View {
    let update: PendingUpdate
    let onDiscard: () -> Void

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
                }
            }

            Spacer()

            Button(role: .destructive) {
                onDiscard()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var statusChangeLabel: String {
        if update.task.status.isComplete {
            return "→ incomplete"
        } else {
            return "→ done"
        }
    }
}
