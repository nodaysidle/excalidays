import XCTest
@testable import Excalidays

@MainActor
final class OrganizerStoreTests: XCTestCase {
    func testRecordOpeningUpsertsByPathHint() throws {
        let store = OrganizerStore(inMemory: true)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("organizer-v1-test.excalidraw")
        try Data("{}".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        store.recordOpening(of: url)
        store.recordOpening(of: url)
        let recents = try store.fetchRecents()
        XCTAssertEqual(recents.filter { $0.pathHint == url.path }.count, 1)
        XCTAssertEqual(recents.first?.displayName, "organizer-v1-test")
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
