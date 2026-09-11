import XCTest
@testable import Excalidays

@MainActor
final class OrganizerStoreTests: XCTestCase {
    func testRecordOpeningUpsertsByPathHint() throws {
        let store = OrganizerStore(inMemory: true)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("organizer-polish-test.excalidraw")
        try Data("{}".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        store.recordOpening(of: url)
        store.recordOpening(of: url)
        let recents = try store.fetchRecents()
        XCTAssertEqual(recents.filter { $0.pathHint == url.path }.count, 1)
        XCTAssertEqual(recents.first?.displayName, "organizer-polish-test")
    }

    func testFavoriteAndTags() throws {
        let store = OrganizerStore(inMemory: true)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("organizer-tags-test.excalidraw")
        try Data("{}".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        store.recordOpening(of: url)
        let drawing = try XCTUnwrap(try store.fetchRecents().first)
        store.toggleFavorite(drawing)
        store.setTags(drawing, tags: ["Draft", " Client "])
        XCTAssertTrue(drawing.isFavorite)
        XCTAssertEqual(drawing.tags, ["Draft", "Client"])
        let favorites = try store.fetchDrawings(filter: .favorites)
        XCTAssertEqual(favorites.count, 1)
        let tagged = try store.fetchDrawings(filter: .tag("draft"))
        XCTAssertEqual(tagged.count, 1)
    }

    func testShowOrganizerMenuActionsExist() {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        let fileMenu = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == "File" })?.submenu
        XCTAssertNotNil(fileMenu?.item(withTitle: "Show Organizer"))
        let windowMenu = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == "Window" })?.submenu
        XCTAssertNotNil(windowMenu?.item(withTitle: "Organizer"))
    }
}
