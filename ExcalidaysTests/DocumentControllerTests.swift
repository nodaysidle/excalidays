import AppKit
import XCTest
@testable import Excalidays

@MainActor
final class DocumentControllerTests: XCTestCase {
    func testDeclaredExcalidrawTypeCreatesExcalidaysDocument() throws {
        let document = try NSDocumentController.shared.makeUntitledDocument(ofType: "com.excalidraw.excalidraw")
        XCTAssertTrue(document is ExcalidaysDocument)
        document.close()
    }

    func testCoordinatorCreatesExcalidaysDocumentWindow() throws {
        let coordinator = AppCoordinator()

        let createdDocument = try coordinator.createNewDocument()

        XCTAssertFalse(createdDocument.windowControllers.isEmpty)
        XCTAssertTrue(NSDocumentController.shared.documents.contains { $0 === createdDocument })
        createdDocument.close()
    }

    func testNewAndOpenMenuItemsTargetDocumentController() {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let fileMenu = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == "File" })?.submenu
        XCTAssertTrue(fileMenu?.item(withTitle: "New Drawing")?.target === delegate)
        XCTAssertTrue(fileMenu?.item(withTitle: "Open…")?.target === delegate)
    }
}
