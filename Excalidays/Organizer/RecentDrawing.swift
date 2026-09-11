import Foundation
import SwiftData

/// Organizer v1 catalog row: a recently opened/saved drawing.
/// Favorites, tags, thumbnails, and workspaces are intentionally out of scope.
@Model
final class RecentDrawing {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var pathHint: String
    var bookmarkData: Data
    var lastOpenedAt: Date

    init(id: UUID = UUID(), displayName: String, pathHint: String, bookmarkData: Data, lastOpenedAt: Date = .now) {
        self.id = id
        self.displayName = displayName
        self.pathHint = pathHint
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
    }
}
