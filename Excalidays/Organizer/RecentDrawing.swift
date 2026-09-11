import Foundation
import SwiftData

/// Catalog row for a drawing the user has opened, saved, or imported from a workspace.
/// Organizer is a side door into Open — never a replacement document window.
@Model
final class RecentDrawing {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var pathHint: String
    var bookmarkData: Data
    var lastOpenedAt: Date
    var isFavorite: Bool
    /// Comma-separated tags (trimmed, lowercased for matching).
    var tagsCSV: String
    var thumbnailPNG: Data?
    /// Optional link to a `WorkspaceFolder.id`.
    var workspaceID: UUID?

    init(
        id: UUID = UUID(),
        displayName: String,
        pathHint: String,
        bookmarkData: Data,
        lastOpenedAt: Date = .now,
        isFavorite: Bool = false,
        tagsCSV: String = "",
        thumbnailPNG: Data? = nil,
        workspaceID: UUID? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.pathHint = pathHint
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
        self.isFavorite = isFavorite
        self.tagsCSV = tagsCSV
        self.thumbnailPNG = thumbnailPNG
        self.workspaceID = workspaceID
    }

    var tags: [String] {
        tagsCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func setTags(_ tags: [String]) {
        let normalized = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        tagsCSV = normalized.joined(separator: ",")
    }
}

@Model
final class WorkspaceFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var pathHint: String
    var bookmarkData: Data
    var addedAt: Date

    init(id: UUID = UUID(), name: String, pathHint: String, bookmarkData: Data, addedAt: Date = .now) {
        self.id = id
        self.name = name
        self.pathHint = pathHint
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
    }
}
