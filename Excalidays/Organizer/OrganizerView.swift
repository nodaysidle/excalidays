import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Organizer polish: recents, favorites, tags, workspaces, thumbnails, missing-file recovery.
/// Open always goes through the shared NSDocumentController path via `onOpen`.
struct OrganizerView: View {
    @State private var filter: OrganizerFilter = .recents
    @State private var drawings: [RecentDrawing] = []
    @State private var workspaces: [WorkspaceFolder] = []
    @State private var tags: [String] = []
    @State private var selection: UUID?
    @State private var errorMessage: String?
    @State private var tagDraft: String = ""

    var onOpen: (URL, @escaping () -> Void) -> Void

    private var store: OrganizerStore { .shared }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { filterIdentity },
                set: { applyFilterIdentity($0) }
            )) {
                Section("Library") {
                    Label("Recents", systemImage: "clock").tag("recents")
                    Label("Favorites", systemImage: "star.fill").tag("favorites")
                    Label("Missing", systemImage: "exclamationmark.triangle").tag("missing")
                }
                Section("Tags") {
                    if tags.isEmpty {
                        Text("No tags yet")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(tags, id: \.self) { tag in
                            Label(tag, systemImage: "tag").tag("tag:\(tag)")
                        }
                    }
                }
                Section("Workspaces") {
                    ForEach(workspaces, id: \.id) { workspace in
                        Label(workspace.name, systemImage: "folder").tag("ws:\(workspace.id.uuidString)")
                            .contextMenu {
                                Button("Refresh Folder") {
                                    store.syncWorkspace(workspace)
                                    reload()
                                }
                                Button("Remove Workspace", role: .destructive) {
                                    store.removeWorkspace(workspace)
                                    filter = .recents
                                    reload()
                                }
                            }
                    }
                    Button("Add Folder…", action: addWorkspace)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
        } detail: {
            VStack(spacing: 0) {
                header
                Divider()
                content
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(8)
                }
                Divider()
                footer
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear(perform: reload)
    }

    private var filterIdentity: String {
        switch filter {
        case .recents: return "recents"
        case .favorites: return "favorites"
        case .missing: return "missing"
        case .tag(let tag): return "tag:\(tag)"
        case .workspace(let id): return "ws:\(id.uuidString)"
        }
    }

    private func applyFilterIdentity(_ value: String?) {
        guard let value else { return }
        if value == "recents" { filter = .recents }
        else if value == "favorites" { filter = .favorites }
        else if value == "missing" { filter = .missing }
        else if value.hasPrefix("tag:") {
            filter = .tag(String(value.dropFirst(4)))
        } else if value.hasPrefix("ws:"), let id = UUID(uuidString: String(value.dropFirst(3))) {
            filter = .workspace(id)
        }
        reload()
    }

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.headline)
            Spacer()
            Button("Refresh", action: reload)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerTitle: String {
        switch filter {
        case .recents: return "Recents"
        case .favorites: return "Favorites"
        case .missing: return "Missing Files"
        case .tag(let tag): return "Tag: \(tag)"
        case .workspace(let id):
            return workspaces.first(where: { $0.id == id })?.name ?? "Workspace"
        }
    }

    @ViewBuilder
    private var content: some View {
        if drawings.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptySymbol,
                description: Text(emptyDescription)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selection) {
                ForEach(drawings, id: \.id) { drawing in
                    DrawingRow(drawing: drawing, isMissing: !store.fileExists(for: drawing))
                        .tag(drawing.id)
                        .contextMenu { contextMenu(for: drawing) }
                        .onTapGesture(count: 2) { open(drawing) }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .missing: return "No Missing Files"
        case .favorites: return "No Favorites"
        case .tag: return "No Drawings With This Tag"
        case .workspace: return "No Drawings In Workspace"
        case .recents: return "No Recent Drawings"
        }
    }

    private var emptySymbol: String {
        switch filter {
        case .missing: return "checkmark.circle"
        case .favorites: return "star"
        default: return "clock"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .recents: return "Open or save a drawing and it will show up here."
        case .favorites: return "Star a drawing to pin it here."
        case .missing: return "Missing drawings appear when a bookmark can no longer be resolved."
        case .tag: return "Add tags from the footer when a drawing is selected."
        case .workspace: return "Add a folder workspace, then Refresh Folder."
        }
    }

    @ViewBuilder
    private func contextMenu(for drawing: RecentDrawing) -> some View {
        Button("Open") { open(drawing) }
        Button(drawing.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            store.toggleFavorite(drawing)
            reload()
        }
        if !store.fileExists(for: drawing) {
            Button("Locate…") { locate(drawing) }
        }
        Button("Remove from Catalog", role: .destructive) {
            store.remove(drawing)
            reload()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Locate…") {
                guard let drawing = selectedDrawing else { return }
                locate(drawing)
            }
            .disabled(selectedDrawing == nil || (selectedDrawing.map { store.fileExists(for: $0) } ?? true))

            Button(selectedDrawing?.isFavorite == true ? "Unfavorite" : "Favorite") {
                guard let drawing = selectedDrawing else { return }
                store.toggleFavorite(drawing)
                reload()
            }
            .disabled(selectedDrawing == nil)

            TextField("Tags (comma-separated)", text: $tagDraft)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
                .disabled(selectedDrawing == nil)
                .onSubmit(applyTags)

            Button("Apply Tags", action: applyTags)
                .disabled(selectedDrawing == nil)

            Spacer()

            Button("Open") {
                guard let drawing = selectedDrawing else { return }
                open(drawing)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedDrawing == nil || !(selectedDrawing.map { store.fileExists(for: $0) } ?? false))
        }
        .padding(12)
        .onChange(of: selection) { _, _ in
            tagDraft = selectedDrawing?.tags.joined(separator: ", ") ?? ""
        }
    }

    private var selectedDrawing: RecentDrawing? {
        guard let selection else { return nil }
        return drawings.first { $0.id == selection }
    }

    private func reload() {
        drawings = (try? store.fetchDrawings(filter: filter)) ?? []
        workspaces = (try? store.fetchWorkspaces()) ?? []
        tags = (try? store.allTags()) ?? []
        errorMessage = nil
        if let selection, !drawings.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
        tagDraft = selectedDrawing?.tags.joined(separator: ", ") ?? ""
    }

    private func applyTags() {
        guard let drawing = selectedDrawing else { return }
        let parts = tagDraft.split(separator: ",").map(String.init)
        store.setTags(drawing, tags: parts)
        reload()
    }

    private func open(_ drawing: RecentDrawing) {
        do {
            let url = try store.resolveURL(for: drawing)
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access \(drawing.displayName). Use Locate… or File → Open…"
                return
            }
            onOpen(url) {
                url.stopAccessingSecurityScopedResource()
            }
            store.recordOpening(of: url) // updates lastOpenedAt + debounce-safe
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: reload)
        } catch {
            errorMessage = "Missing file — \(drawing.pathHint). Use Locate…"
        }
    }

    private func locate(_ drawing: RecentDrawing) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(importedAs: "com.excalidraw.excalidraw")]
        panel.message = "Locate “\(drawing.displayName)”"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.relink(drawing, to: url)
            reload()
        } catch {
            errorMessage = "Could not relink: \(error.localizedDescription)"
        }
    }

    private func addWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder of .excalidraw drawings"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let workspace = try store.addWorkspace(folderURL: url)
            filter = .workspace(workspace.id)
            reload()
        } catch {
            errorMessage = "Could not add workspace: \(error.localizedDescription)"
        }
    }
}

private struct DrawingRow: View {
    let drawing: RecentDrawing
    let isMissing: Bool

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(drawing.displayName)
                        .font(.body.weight(.medium))
                    if drawing.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                    if isMissing {
                        Text("Missing")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
                Text(drawing.pathHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !drawing.tags.isEmpty {
                    Text(drawing.tags.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .opacity(isMissing ? 0.75 : 1)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = drawing.thumbnailPNG, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
