import XCTest
@testable import Excalidays

final class CanvasURLPolicyTests: XCTestCase {
    func testAllowsFilesInsideRuntimeRoot() {
        let root = URL(fileURLWithPath: "/Applications/Excalidays.app/Contents/Resources/ExcalidrawCanvas", isDirectory: true)
        let policy = CanvasURLPolicy(resourceRoot: root)
        XCTAssertTrue(policy.allows(root.appendingPathComponent("index.html")))
        XCTAssertTrue(policy.allows(root.appendingPathComponent("assets/runtime.js")))
    }

    func testDeniesNetworkAndEscapedFiles() {
        let root = URL(fileURLWithPath: "/Applications/Excalidays.app/Contents/Resources/ExcalidrawCanvas", isDirectory: true)
        let policy = CanvasURLPolicy(resourceRoot: root)
        XCTAssertFalse(policy.allows(URL(string: "https://excalidraw.com")!))
        XCTAssertFalse(policy.allows(root.appendingPathComponent("../Info.plist").standardizedFileURL))
    }

    func testAllowsOnlyCanvasHostForCustomRuntimeScheme() {
        let root = URL(fileURLWithPath: "/Applications/Excalidays.app/Contents/Resources/ExcalidrawCanvas", isDirectory: true)
        let policy = CanvasURLPolicy(resourceRoot: root)

        XCTAssertTrue(policy.allows(URL(string: "excalidays://canvas/index.html")!))
        XCTAssertFalse(policy.allows(URL(string: "excalidays://other/index.html")!))
    }
}
