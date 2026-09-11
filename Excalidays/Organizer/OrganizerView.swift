import AppKit
import SwiftUI
import SwiftData

/// Recents list only — open uses the shared NSDocumentController path via the coordinator.
struct OrganizerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recents: [RecentDrawing] = []
    @State private var errorMessage: String?
    var onOpen: (URL) -> Void
    var onRefresh: () -> [RecentDrawing]
    var onRemove: (RecentDrawing) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if recents.isEmpty {
                ContentUnavailableView(
                    "No Recent Drawings",
                    systemImage: "clock",
                    description: Text("Open or save a drawing and it will show up here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(recents, id: \.id) { recent in
                        RecentRow(recent: recent)
                            .tag(recent.id)
                            .contextMenu {
                                Button("Open") { open(recent) }
                                Button("Remove from Recents", role: .destructive) {
                                    onRemove(recent)
                                    reload()
                                }
                            }
                            .onTapGesture(count: 2) { open(recent) }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(8)
            }
            Divider()
            footer
        }
        .frame(minWidth: 420, minHeight: 360)
        .onAppear(perform: reload)
    }

    @State private var selection: UUID?

    private var header: some View {
        HStack {
            Text("Recents")
                .font(.headline)
            Spacer()
            Button("Refresh", action: reload)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            Button("Remove") {
                guard let id = selection, let recent = recents.first(where: { $0.id == id }) else { return }
                onRemove(recent)
                reload()
            }
            .disabled(selection == nil)
            Spacer()
            Button("Open") {
                guard let id = selection, let recent = recents.first(where: { $0.id == id }) else { return }
                open(recent)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selection == nil)
        }
        .padding(12)
    }

    private func reload() {
        recents = onRefresh()
        errorMessage = nil
        if let selection, !recents.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
    }

    private func open(_ recent: RecentDrawing) {
        do {
            let url = try OrganizerStore.shared.resolveURL(for: recent)
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access \(recent.displayName). Re-open it via File → Open…"
                return
            }
            // Keep access until NSDocumentController takes over the user-selected file.
            onOpen(url)
            // Stop after a short delay so openDocument can start reading.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                url.stopAccessingSecurityScopedResource()
            }
            recent.lastOpenedAt = .now
            reload()
        } catch {
            errorMessage = "Missing file — \(recent.pathHint)"
        }
    }
}

private struct RecentRow: View {
    let recent: RecentDrawing

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recent.displayName)
                .font(.body.weight(.medium))
            Text(recent.pathHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }
}
