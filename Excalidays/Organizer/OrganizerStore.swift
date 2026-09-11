import AppKit
import Foundation
import QuickLookThumbnailing
import SwiftData
import UniformTypeIdentifiers

enum OrganizerFilter: Equatable {
    case recents
    case favorites
    case tag(String)
    case workspace(UUID)
    case missing
}

/// SwiftData-backed catalog. Side door into open — not a home screen or cloud library.
@MainActor
final class OrganizerStore {
    static let shared: OrganizerStore = {
        do {
            return try OrganizerStore(configurationName: "ExcalidaysOrganizer", inMemory: false)
        } catch {
            NSLog("OrganizerStore: falling back to in-memory catalog — \(error.localizedDescription)")
            return try! OrganizerStore(configurationName: "ExcalidaysOrganizerFallback", inMemory: true)
        }
    }()

    let container: ModelContainer
    private let context: ModelContext
    private var lastRecordedPath: String?
    private var lastRecordedAt: Date?

    init(configurationName: String, inMemory: Bool) throws {
        let schema = Schema([RecentDrawing.self, WorkspaceFolder.self])
        let configuration = ModelConfiguration(
            configurationName,
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = true
    }

    /// Test helper.
    convenience init(inMemory: Bool) {
        try! self.init(configurationName: "ExcalidaysOrganizerInMemory-\(UUID().uuidString)", inMemory: inMemory)
    }

    // MARK: - Fetch

    func fetchDrawings(filter: OrganizerFilter, limit: Int = 200) throws -> [RecentDrawing] {
        var descriptor = FetchDescriptor<RecentDrawing>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let all = try context.fetch(descriptor)
        switch filter {
        case .recents:
            return all
        case .favorites:
            return all.filter(\.isFavorite)
        case .tag(let tag):
            let needle = tag.lowercased()
            return all.filter { $0.tags.contains { $0.lowercased() == needle } }
        case .workspace(let id):
            return all.filter { $0.workspaceID == id }
        case .missing:
            return all.filter { !fileExists(for: $0) }
        }
    }

    func fetchRecents(limit: Int = 50) throws -> [RecentDrawing] {
        try fetchDrawings(filter: .recents, limit: limit)
    }

    func fetchWorkspaces() throws -> [WorkspaceFolder] {
        try context.fetch(
            FetchDescriptor<WorkspaceFolder>(sortBy: [SortDescriptor(\.name)])
        )
    }

    func allTags() throws -> [String] {
        let drawings = try fetchRecents(limit: 500)
        var set = Set<String>()
        for drawing in drawings {
            for tag in drawing.tags { set.insert(tag) }
        }
        return set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func fileExists(for drawing: RecentDrawing) -> Bool {
        do {
            let url = try resolveURL(for: drawing)
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            return FileManager.default.isReadableFile(atPath: url.path)
        } catch {
            return FileManager.default.isReadableFile(atPath: drawing.pathHint)
        }
    }

    // MARK: - Mutate drawings

    /// Upsert a catalog entry. Debounced so open+read hooks do not double-insert.
    func recordOpening(of url: URL, workspaceID: UUID? = nil) {
        guard url.isFileURL else { return }
        let pathHint = url.path
        let now = Date()
        if lastRecordedPath == pathHint, let last = lastRecordedAt, now.timeIntervalSince(last) < 1.5 {
            return
        }
        lastRecordedPath = pathHint
        lastRecordedAt = now

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let displayName = url.deletingPathExtension().lastPathComponent
            let existing = try context.fetch(
                FetchDescriptor<RecentDrawing>(predicate: #Predicate { $0.pathHint == pathHint })
            )
            let row: RecentDrawing
            if let found = existing.first {
                found.displayName = displayName
                found.bookmarkData = bookmark
                found.lastOpenedAt = now
                if let workspaceID { found.workspaceID = workspaceID }
                row = found
            } else {
                row = RecentDrawing(
                    displayName: displayName,
                    pathHint: pathHint,
                    bookmarkData: bookmark,
                    lastOpenedAt: now,
                    workspaceID: workspaceID
                )
                context.insert(row)
            }
            try context.save()
            refreshThumbnail(for: row, fileURL: url)
        } catch {
            NSLog("OrganizerStore.recordOpening failed: \(error.localizedDescription)")
        }
    }

    func remove(_ drawing: RecentDrawing) {
        context.delete(drawing)
        try? context.save()
    }

    func toggleFavorite(_ drawing: RecentDrawing) {
        drawing.isFavorite.toggle()
        try? context.save()
    }

    func setTags(_ drawing: RecentDrawing, tags: [String]) {
        drawing.setTags(tags)
        try? context.save()
    }

    /// Replace a broken bookmark after the user locates the file again.
    func relink(_ drawing: RecentDrawing, to url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        drawing.bookmarkData = bookmark
        drawing.pathHint = url.path
        drawing.displayName = url.deletingPathExtension().lastPathComponent
        drawing.lastOpenedAt = .now
        try context.save()
        refreshThumbnail(for: drawing, fileURL: url)
    }

    func resolveURL(for drawing: RecentDrawing) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: drawing.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let refreshed = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                drawing.bookmarkData = refreshed
                drawing.pathHint = url.path
                try? context.save()
            }
        }
        return url
    }

    // MARK: - Workspaces

    func addWorkspace(folderURL: URL) throws -> WorkspaceFolder {
        let bookmark = try folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let workspace = WorkspaceFolder(
            name: folderURL.lastPathComponent,
            pathHint: folderURL.path,
            bookmarkData: bookmark
        )
        context.insert(workspace)
        try context.save()
        syncWorkspace(workspace)
        return workspace
    }

    func removeWorkspace(_ workspace: WorkspaceFolder) {
        let id = workspace.id
        if let drawings = try? fetchDrawings(filter: .workspace(id)) {
            for drawing in drawings where drawing.workspaceID == id {
                drawing.workspaceID = nil
            }
        }
        context.delete(workspace)
        try? context.save()
    }

    func resolveWorkspaceURL(_ workspace: WorkspaceFolder) throws -> URL {
        var isStale = false
        return try URL(
            resolvingBookmarkData: workspace.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    /// Scan a workspace folder for `.excalidraw` files and upsert catalog rows.
    func syncWorkspace(_ workspace: WorkspaceFolder) {
        do {
            let folder = try resolveWorkspaceURL(workspace)
            guard folder.startAccessingSecurityScopedResource() else { return }
            defer { folder.stopAccessingSecurityScopedResource() }
            let urls = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "excalidraw" }
            for url in urls {
                recordOpening(of: url, workspaceID: workspace.id)
            }
        } catch {
            NSLog("OrganizerStore.syncWorkspace failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Thumbnails

    func refreshThumbnail(for drawing: RecentDrawing, fileURL: URL) {
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: 128, height: 128),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { [weak self] representation, _, error in
            guard let self, let representation, error == nil else { return }
            let image = representation.nsImage
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return }
            Task { @MainActor in
                drawing.thumbnailPNG = png
                try? self.context.save()
            }
        }
    }
}
