import AppKit
import WebKit
import XCTest
@testable import Excalidays

/// End-to-end tests through a real WKWebView hosting the bundled Excalidraw
/// runtime, exercising the same bridge calls the document layer uses.
@MainActor
final class CanvasEditRoundTripIntegrationTests: XCTestCase {
    private var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    private func fixtureData(_ name: String) throws -> Data {
        try Data(contentsOf: fixturesDirectory.appendingPathComponent(name))
    }

    /// Polls until `condition` returns a non-nil value; returns it, or nil on timeout.
    private func poll<T>(timeout: TimeInterval = 30, _ condition: @MainActor () async throws -> T?) async throws -> T? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = try await condition() { return value }
            try await Task.sleep(for: .milliseconds(100))
        }
        return try await condition()
    }

    /// Keeps the web view hosted in a live window for the whole test, mirroring
    /// the app's document window (rendering/animations continue offscreen).
    private var hostWindows: [NSWindow] = []

    private func hostCanvas(_ webView: WKWebView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        hostWindows.append(window)
    }

    override func tearDown() async throws {
        hostWindows.removeAll()
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeRectangle(id: String, x: Double, y: Double, width: Double = 60, height: Double = 40) -> [String: Any] {
        [
            "id": id,
            "type": "rectangle",
            "x": x,
            "y": y,
            "width": width,
            "height": height,
            "angle": 0,
            "strokeColor": "#000000",
            "backgroundColor": "transparent",
            "fillStyle": "solid",
            "strokeWidth": 2,
            "strokeStyle": "solid",
            "roughness": 1,
            "opacity": 100,
            "groupIds": [],
            "frameId": nil,
            "roundness": nil,
            "seed": 42,
            "version": 1,
            "versionNonce": 1,
            "isDeleted": false,
            "boundElements": nil,
            "updated": 1,
            "link": nil,
            "locked": false,
        ] as [String: Any]
    }

    private func makeScene(elements: [[String: Any]]) throws -> Data {
        let root: [String: Any] = [
            "type": "excalidraw",
            "version": 2,
            "source": "on-disk-source",
            "elements": elements,
            "appState": ["viewBackgroundColor": "#ffffff"],
            "files": [:],
        ]
        return try JSONSerialization.data(withJSONObject: root)
    }

    private func elementIDs(in data: Data) throws -> Set<String> {
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let elements = try XCTUnwrap(parsed["elements"] as? [[String: Any]])
        return Set(elements.compactMap { $0["id"] as? String })
    }

    // MARK: - FIX 7: canvas round-trip preserves unknown fields and new elements

    func testSnapshotThroughRealWKWebViewPreservesUnknownFields() async throws {
        let fixture = try fixtureData("unknown-fields.excalidraw")
        let session = CanvasSession(initialSceneData: fixture)
        let webView = session.makeWebView()
        hostCanvas(webView)

        // Poll until the runtime reaches ready and a snapshot round-trips the
        // fixture's known fields (source + empty elements) through the runtime.
        let snapshotData = try await poll { () -> Data? in
            guard session.runtimeState == .ready,
                  let snapshot = try? await session.requestSnapshot(),
                  let parsed = try? JSONSerialization.jsonObject(with: snapshot) as? [String: Any],
                  (parsed["elements"] as? [[String: Any]])?.isEmpty == true,
                  parsed["source"] as? String == "fixture-source" else { return nil }
            return snapshot
        }
        let data = try XCTUnwrap(snapshotData, "canvas never round-tripped the fixture scene")
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Unknown top-level field and source survive the bridge round-trip.
        let futureField = parsed["futureField"] as? [String: Any]
        XCTAssertEqual(
            futureField?["preserve"] as? Bool, true,
            "futureField was not preserved; snapshot keys=\(parsed.keys.sorted())"
        )
        XCTAssertEqual(parsed["source"] as? String, "fixture-source")

        // Embedded binary attachments survive the bridge round-trip.
        let files = parsed["files"] as? [String: Any]
        let fixtureFile = files?["fixture-file"] as? [String: Any]
        XCTAssertNotNil(fixtureFile, "fixture-file was not preserved; files=\(files ?? [:])")
        XCTAssertEqual(fixtureFile?["mimeType"] as? String, "image/png")
        XCTAssertTrue((fixtureFile?["dataURL"] as? String)?.hasPrefix("data:image/png;base64,") == true)

        session.destroy()
    }

    // MARK: - FIX 2: revert-to-saved reloads the visible canvas

    func testRevertWithLiveSessionReloadsVisibleCanvasEndToEnd() async throws {
        let document = ExcalidaysDocument()
        let sceneA = try makeScene(elements: [makeRectangle(id: "element-a", x: 0, y: 0)])
        try document.read(from: sceneA, ofType: "com.excalidraw.excalidraw")
        let session = document.canvasSession
        hostCanvas(session.makeWebView())

        // Wait for the initial scene to be live in the canvas.
        let initialIDs = try await poll { () -> Set<String>? in
            guard session.runtimeState == .ready,
                  let snapshot = try? await session.requestSnapshot(),
                  let ids = try? self.elementIDs(in: snapshot),
                  ids == ["element-a"] else { return nil }
            return ids
        }
        XCTAssertEqual(initialIDs, ["element-a"])

        // Revert: the on-disk bytes are replaced with a different scene.
        let sceneB = try makeScene(elements: [makeRectangle(id: "element-b", x: 40, y: 20)])
        try document.read(from: sceneB, ofType: "com.excalidraw.excalidraw")

        // The visible canvas must now reflect the reverted bytes.
        let reloadedIDs = try await poll { () -> Set<String>? in
            guard session.sceneReloadCount >= 1,
                  let snapshot = try? await session.requestSnapshot(),
                  let ids = try? self.elementIDs(in: snapshot),
                  ids == ["element-b"] else { return nil }
            return ids
        }
        XCTAssertEqual(
            reloadedIDs,
            ["element-b"],
            "revert did not reload the visible canvas (sceneReloadCount=\(session.sceneReloadCount))"
        )
        document.close()
    }

    // MARK: - FIX 6: Try Again reboots a failed runtime back to ready

    func testRetryAfterReportedFailureRebootsRuntimeToReady() async throws {
        let fixture = try fixtureData("minimal.excalidraw")
        let session = CanvasSession(initialSceneData: fixture)
        hostCanvas(session.makeWebView())

        // Reach ready first (proves the initial load path), then simulate a crash.
        let firstReady = try await poll { session.runtimeState == .ready ? true : nil }
        XCTAssertEqual(firstReady, true)

        session.reportCrash()
        guard case .failed = session.runtimeState else {
            XCTFail("expected failed state after reportCrash, got \(session.runtimeState)")
            session.destroy()
            return
        }

        // FIX 6: retryLoad recreates the web view and reloads the bundled page
        // so the runtime re-fires `ready` and recovers to a live canvas.
        session.retryLoad()
        XCTAssertEqual(session.runtimeState, .loading)
        XCTAssertFalse(session.canUndo)
        XCTAssertFalse(session.canRedo)

        // Re-host the recreated web view (in the app SwiftUI swaps it via .id()).
        if let newWebView = session.currentWebView {
            hostCanvas(newWebView)
        }

        let secondReady = try await poll { session.runtimeState == .ready ? true : nil }
        XCTAssertEqual(secondReady, true, "canvas did not recover after retryLoad")
        session.destroy()
    }
}
