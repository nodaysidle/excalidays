import AppKit
import Foundation
import SwiftData

/// SwiftData-backed recents catalog (Application Support). Side door into open — not a home screen.
@MainActor
final class OrganizerStore {
    static let shared = OrganizerStore()

    let container: ModelContainer
    private let context: ModelContext

    private init() {
        let schema = Schema([RecentDrawing.self])
        let configuration = ModelConfiguration(
            "ExcalidaysOrganizer",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            context = ModelContext(container)
            context.autosaveEnabled = true
        } catch {
            fatalError("Failed to create Organizer ModelContainer: \(error)")
        }
    }

    /// Test / preview initializer with an in-memory store.
    init(inMemory: Bool) {
        let schema = Schema([RecentDrawing.self])
        let configuration = ModelConfiguration(
            "ExcalidaysOrganizerInMemory",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            context = ModelContext(container)
            context.autosaveEnabled = true
        } catch {
            fatalError("Failed to create in-memory Organizer ModelContainer: \(error)")
        }
        _ = inMemory
    }

    func fetchRecents(limit: Int = 50) throws -> [RecentDrawing] {
        var descriptor = FetchDescriptor<RecentDrawing>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// Upsert a recent entry from a user-selected / opened file URL.
    func recordOpening(of url: URL) {
        guard url.isFileURL else { return }
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let pathHint = url.path
            let displayName = url.deletingPathExtension().lastPathComponent

            let existing = try context.fetch(
                FetchDescriptor<RecentDrawing>(
                    predicate: #Predicate { $0.pathHint == pathHint }
                )
            )
            if let row = existing.first {
                row.displayName = displayName
                row.bookmarkData = bookmark
                row.lastOpenedAt = .now
            } else {
                context.insert(
                    RecentDrawing(
                        displayName: displayName,
                        pathHint: pathHint,
                        bookmarkData: bookmark
                    )
                )
            }
            try context.save()
        } catch {
            // Catalog is best-effort; never block document open/save.
            NSLog("OrganizerStore.recordOpening failed: \(error.localizedDescription)")
        }
    }

    func remove(_ recent: RecentDrawing) {
        context.delete(recent)
        try? context.save()
    }

    /// Resolve a recent bookmark for opening. Caller must stop accessing when done.
    func resolveURL(for recent: RecentDrawing) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: recent.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            // Refresh bookmark while we still have access.
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let refreshed = try? url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    recent.bookmarkData = refreshed
                    recent.pathHint = url.path
                    try? context.save()
                }
            }
        }
        return url
    }
}
