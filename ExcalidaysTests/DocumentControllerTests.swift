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

    func testOpenFixtureURLUsesSharedDocumentControllerPath() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("minimal.excalidraw")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixtureURL.path), "missing fixture \(fixtureURL.path)")

        let expectation = expectation(description: "openDocument via NSDocumentController")
        var opened: NSDocument?
        var openError: Error?

        NSDocumentController.shared.openDocument(withContentsOf: fixtureURL, display: false) { document, _, error in
            opened = document
            openError = error
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        XCTAssertNil(openError)
        let document = try XCTUnwrap(opened as? ExcalidaysDocument)
        XCTAssertTrue(NSDocumentController.shared.documents.contains { $0 === document })
        document.close()
    }

    func testExcalidaysDocumentDeclaresExcalidrawReadableWritableTypes() {
        XCTAssertEqual(ExcalidaysDocument.readableTypes, ["com.excalidraw.excalidraw"])
        XCTAssertEqual(ExcalidaysDocument.writableTypes, ["com.excalidraw.excalidraw"])
    }
}
