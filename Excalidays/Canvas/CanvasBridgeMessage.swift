import Foundation

enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

enum CanvasBridgeKind: String, Codable, Sendable { case request, response, event }

enum CanvasBridgeOperation: String, Codable, Sendable {
    case initialize, loadScene, requestSnapshot, updateTheme, performCommand
    case importBinaryFile, exportScene, zoomToFit, zoomToSelection, setReadOnly, focusCanvas
    case ready, dirtyStateChanged, selectionChanged, documentMetadataChanged, commandStateChanged, runtimeError
}

struct CanvasBridgeMessage: Codable, Equatable, Sendable {
    static let protocolVersion = 1
    static let maximumEventByteCount = 64 * 1024

    let protocolVersion: Int
    let id: String
    let kind: CanvasBridgeKind
    let operation: CanvasBridgeOperation
    let payload: JSONValue

    init(id: String = UUID().uuidString, kind: CanvasBridgeKind, operation: CanvasBridgeOperation, payload: JSONValue = .object([:])) {
        self.protocolVersion = Self.protocolVersion
        self.id = id
        self.kind = kind
        self.operation = operation
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .protocolVersion)
        guard version == Self.protocolVersion else {
            throw DecodingError.dataCorruptedError(forKey: .protocolVersion, in: container, debugDescription: "Unsupported bridge protocol")
        }
        protocolVersion = version
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(CanvasBridgeKind.self, forKey: .kind)
        operation = try container.decode(CanvasBridgeOperation.self, forKey: .operation)
        payload = try container.decodeIfPresent(JSONValue.self, forKey: .payload) ?? .object([:])
        guard Self.allows(operation: operation, for: kind) else {
            throw DecodingError.dataCorruptedError(forKey: .operation, in: container, debugDescription: "Operation is not valid for bridge kind")
        }
    }

    static func decode(_ data: Data, maximumByteCount: Int = SceneEnvelope.maximumByteCount) throws -> Self {
        guard data.count <= maximumByteCount else { throw DocumentError.sceneTooLarge }
        return try JSONDecoder().decode(Self.self, from: data)
    }

    private static func allows(operation: CanvasBridgeOperation, for kind: CanvasBridgeKind) -> Bool {
        switch kind {
        case .request:
            return [.initialize, .loadScene, .requestSnapshot, .updateTheme, .performCommand,
                    .importBinaryFile, .exportScene, .zoomToFit, .zoomToSelection, .setReadOnly,
                    .focusCanvas].contains(operation)
        case .event:
            return [.ready, .dirtyStateChanged, .selectionChanged, .documentMetadataChanged,
                    .commandStateChanged, .runtimeError].contains(operation)
        case .response:
            return ![.ready, .dirtyStateChanged, .selectionChanged, .documentMetadataChanged,
                     .commandStateChanged, .runtimeError].contains(operation)
        }
    }
}
