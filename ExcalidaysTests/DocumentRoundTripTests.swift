import AppKit
import XCTest
@testable import Excalidays

@MainActor
final class DocumentRoundTripTests: XCTestCase {
    private var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    func testRoundTripMinimalFixture() throws {
        let fixtureURL = fixturesDirectory.appendingPathComponent("minimal.excalidraw")
        let originalData = try Data(contentsOf: fixtureURL)

        let document = ExcalidaysDocument()
        try document.read(from: originalData, ofType: "com.excalidraw.excalidraw")

        let writtenData = try document.data(ofType: "com.excalidraw.excalidraw")
        XCTAssertFalse(writtenData.isEmpty)

        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: writtenData) as? [String: Any])
        XCTAssertEqual(parsed["type"] as? String, "excalidraw")
        XCTAssertEqual(parsed["version"] as? Int, 2)
        XCTAssertNotNil(parsed["elements"])
        XCTAssertNotNil(parsed["files"])
        document.close()
    }

    func testRoundTripUnknownFieldsFixturePreservesAttachmentsAndFutureFields() throws {
        let fixtureURL = fixturesDirectory.appendingPathComponent("unknown-fields.excalidraw")
        let originalData = try Data(contentsOf: fixtureURL)

        let document = ExcalidaysDocument()
        try document.read(from: originalData, ofType: "com.excalidraw.excalidraw")

        let writtenData = try document.data(ofType: "com.excalidraw.excalidraw")
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: writtenData) as? [String: Any])

        XCTAssertEqual(parsed["source"] as? String, "fixture-source")

        let futureField = try XCTUnwrap(parsed["futureField"] as? [String: Any])
        XCTAssertEqual(futureField["preserve"] as? Bool, true)

        let files = try XCTUnwrap(parsed["files"] as? [String: Any])
        let fixtureFile = try XCTUnwrap(files["fixture-file"] as? [String: Any])
        XCTAssertEqual(fixtureFile["mimeType"] as? String, "image/png")
        XCTAssertTrue((fixtureFile["dataURL"] as? String)?.hasPrefix("data:image/png;base64,") == true)
        document.close()
    }

    func testUndoRedoMenuItemValidation() throws {
        for doc in NSDocumentController.shared.documents {
            doc.close()
        }
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undoCanvas:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redoCanvas:")), keyEquivalent: "Z")

        // No document open initially
        XCTAssertFalse(delegate.validateMenuItem(undoItem))
        XCTAssertFalse(delegate.validateMenuItem(redoItem))

        // Open a document
        let coordinator = AppCoordinator()
        let document = try coordinator.createNewDocument()

        XCTAssertTrue(delegate.validateMenuItem(undoItem))
        XCTAssertTrue(delegate.validateMenuItem(redoItem))

        // Close the document
        document.close()
        XCTAssertFalse(delegate.validateMenuItem(undoItem))
        XCTAssertFalse(delegate.validateMenuItem(redoItem))
    }
}
