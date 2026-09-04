import XCTest
@testable import Excalidays

final class CanvasBridgeMessageTests: XCTestCase {
    func testDecodesAllowlistedSnapshotRequest() throws {
        let data = Data(#"{"protocolVersion":1,"id":"r1","kind":"request","operation":"requestSnapshot","payload":{}}"#.utf8)
        let message = try JSONDecoder().decode(CanvasBridgeMessage.self, from: data)
        XCTAssertEqual(message.operation, .requestSnapshot)
        XCTAssertEqual(message.id, "r1")
    }

    func testRejectsProtocolMismatch() throws {
        let data = Data(#"{"protocolVersion":2,"id":"r1","kind":"request","operation":"requestSnapshot","payload":{}}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CanvasBridgeMessage.self, from: data))
    }

    func testRejectsUnknownOperation() throws {
        let data = Data(#"{"protocolVersion":1,"id":"r1","kind":"request","operation":"readFileAtPath","payload":{}}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CanvasBridgeMessage.self, from: data))
    }

    func testRejectsPayloadOverConfiguredLimit() {
        let data = Data(#"{"protocolVersion":1,"id":"r1","kind":"request","operation":"loadScene","payload":{"sceneJSON":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}}"#.utf8)
        XCTAssertThrowsError(try CanvasBridgeMessage.decode(data, maximumByteCount: 32))
    }

    func testRejectsEventOperationInRequestEnvelope() {
        let data = Data(#"{"protocolVersion":1,"id":"r1","kind":"request","operation":"ready","payload":{}}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CanvasBridgeMessage.self, from: data))
    }

    func testAcceptsReadyEventEnvelope() throws {
        let data = Data(#"{"protocolVersion":1,"id":"e1","kind":"event","operation":"ready","payload":{}}"#.utf8)
        let message = try JSONDecoder().decode(CanvasBridgeMessage.self, from: data)
        XCTAssertEqual(message.kind, .event)
        XCTAssertEqual(message.operation, .ready)
    }
}
