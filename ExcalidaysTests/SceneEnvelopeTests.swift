import XCTest
@testable import Excalidays

final class SceneEnvelopeTests: XCTestCase {
    func testAcceptsMinimalExcalidrawSceneAndPreservesBytes() throws {
        let data = Data(#"{"type":"excalidraw","version":2,"elements":[],"appState":{},"files":{},"future":{"keep":true}}"#.utf8)
        let envelope = try SceneEnvelope(data: data)
        XCTAssertEqual(envelope.data, data)
    }

    func testRejectsWrongType() {
        let data = Data(#"{"type":"other","elements":[]}"#.utf8)
        XCTAssertThrowsError(try SceneEnvelope(data: data)) { error in
            XCTAssertEqual(error as? DocumentError, .unsupportedSceneType)
        }
    }

    func testRejectsOversizedInputBeforeJSONParsing() {
        let data = Data(repeating: 0x20, count: SceneEnvelope.maximumByteCount + 1)
        XCTAssertThrowsError(try SceneEnvelope(data: data)) { error in
            XCTAssertEqual(error as? DocumentError, .sceneTooLarge)
        }
    }
}
