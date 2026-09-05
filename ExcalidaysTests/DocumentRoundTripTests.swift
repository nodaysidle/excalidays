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

        // Open a document: the canvas has not reported undo/redo availability yet
        let coordinator = AppCoordinator()
        let document = try coordinator.createNewDocument()

        XCTAssertFalse(delegate.validateMenuItem(undoItem))
        XCTAssertFalse(delegate.validateMenuItem(redoItem))

        // Canvas reports undoable (but not redoable) state
        document.canvasSession.handleEvent(bridgeEvent(operation: "commandStateChanged", payload: ["canUndo": true, "canRedo": false]))
        XCTAssertTrue(delegate.validateMenuItem(undoItem))
        XCTAssertFalse(delegate.validateMenuItem(redoItem))

        // Close the document
        document.close()
        XCTAssertFalse(delegate.validateMenuItem(undoItem))
        XCTAssertFalse(delegate.validateMenuItem(redoItem))
    }

    // MARK: - FIX 2: revert-to-saved must reload an existing canvas session

    func testReadWithLiveSessionIssuesSceneReload() async throws {
        let fixtureURL = fixturesDirectory.appendingPathComponent("minimal.excalidraw")
        let document = ExcalidaysDocument()
        try document.read(from: Data(contentsOf: fixtureURL), ofType: "com.excalidraw.excalidraw")

        // Initial open has no session yet: byte-swap only.
        let session = document.canvasSession
        XCTAssertEqual(session.sceneReloadCount, 0)

        // A second read (revert-to-saved) with a live session must push a reload.
        let revertedData = try Data(contentsOf: fixturesDirectory.appendingPathComponent("unknown-fields.excalidraw"))
        try document.read(from: revertedData, ofType: "com.excalidraw.excalidraw")

        for _ in 0..<100 where session.sceneReloadCount == 0 {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(session.sceneReloadCount, 1)
        document.close()
    }

    // MARK: - FIX 5: bridge payload consumption (session level)

    func testDirtyStateChangedForwardsPayloadIsDirtyValue() throws {
        let fixtureURL = fixturesDirectory.appendingPathComponent("minimal.excalidraw")
        let document = ExcalidaysDocument()
        try document.read(from: Data(contentsOf: fixtureURL), ofType: "com.excalidraw.excalidraw")
        let session = document.canvasSession

        var forwarded: [Bool] = []
        session.onDirtyStateChanged = { forwarded.append($0) }

        session.handleEvent(bridgeEvent(operation: "dirtyStateChanged", payload: ["isDirty": true]))
        session.handleEvent(bridgeEvent(operation: "dirtyStateChanged", payload: ["isDirty": false]))
        XCTAssertEqual(forwarded, [true, false])

        // A payload without isDirty must not fire the closure.
        session.handleEvent(bridgeEvent(operation: "dirtyStateChanged", payload: [:]))
        XCTAssertEqual(forwarded, [true, false])
        document.close()
    }

    func testCommandStateChangedUpdatesUndoRedoAvailability() throws {
        let fixtureURL = fixturesDirectory.appendingPathComponent("minimal.excalidraw")
        let document = ExcalidaysDocument()
        try document.read(from: Data(contentsOf: fixtureURL), ofType: "com.excalidraw.excalidraw")
        let session = document.canvasSession

        XCTAssertFalse(session.canUndo)
        XCTAssertFalse(session.canRedo)

        session.handleEvent(bridgeEvent(operation: "commandStateChanged", payload: ["canUndo": true, "canRedo": false]))
        XCTAssertTrue(session.canUndo)
        XCTAssertFalse(session.canRedo)

        session.handleEvent(bridgeEvent(operation: "commandStateChanged", payload: ["canUndo": false, "canRedo": true]))
        XCTAssertFalse(session.canUndo)
        XCTAssertTrue(session.canRedo)
        document.close()
    }

    // MARK: - FIX 1: save must never silently persist stale bytes

    func testSaveReportsFailureWhenCanvasIsUnavailable() throws {
        let fixtureURL = fixturesDirectory.appendingPathComponent("minimal.excalidraw")
        let originalData = try Data(contentsOf: fixtureURL)

        let document = try XCTUnwrap(
            NSDocumentController.shared.makeUntitledDocument(ofType: "com.excalidraw.excalidraw") as? ExcalidaysDocument
        )
        NSDocumentController.shared.addDocument(document)
        try document.read(from: originalData, ofType: "com.excalidraw.excalidraw")
        document.canvasSession.reportCrash()

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("excalidays-save-failure-\(UUID().uuidString).excalidraw")
        let saveExpectation = expectation(description: "save completion")
        var receivedError: Error?
        document.save(to: destination, ofType: "com.excalidraw.excalidraw", for: .saveOperation) { error in
            receivedError = error
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: 5)

        XCTAssertEqual(receivedError as? DocumentError, .canvasUnavailable)
        try? FileManager.default.removeItem(at: destination)
        document.close()
    }

    // MARK: - FIX 5: dirtyStateChanged payload drives change-count transitions

    func testDirtyStateChangedLifecycleTogglesDocumentEditedState() throws {
        let fixtureURL = fixturesDirectory.appendingPathComponent("minimal.excalidraw")
        let document = ExcalidaysDocument()
        try document.read(from: Data(contentsOf: fixtureURL), ofType: "com.excalidraw.excalidraw")
        let session = document.canvasSession

        XCTAssertFalse(document.isDocumentEdited)

        session.handleEvent(bridgeEvent(operation: "dirtyStateChanged", payload: ["isDirty": true]))
        XCTAssertTrue(document.isDocumentEdited)

        // Repeated dirty reports must not corrupt the document state.
        session.handleEvent(bridgeEvent(operation: "dirtyStateChanged", payload: ["isDirty": true]))
        XCTAssertTrue(document.isDocumentEdited)

        // A clean report must clear the edited state.
        session.handleEvent(bridgeEvent(operation: "dirtyStateChanged", payload: ["isDirty": false]))
        XCTAssertFalse(document.isDocumentEdited)

        session.handleEvent(bridgeEvent(operation: "dirtyStateChanged", payload: ["isDirty": false]))
        XCTAssertFalse(document.isDocumentEdited)
        document.close()
    }

    private func bridgeEvent(operation: String, payload: [String: Any]) -> [String: Any] {
        [
            "protocolVersion": 1,
            "id": UUID().uuidString,
            "kind": "event",
            "operation": operation,
            "payload": payload,
        ]
    }
}
