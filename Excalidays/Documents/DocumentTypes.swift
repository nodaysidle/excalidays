import Foundation

struct SceneEnvelope: Sendable, Equatable {
    static let maximumByteCount = 64 * 1024 * 1024
    static let emptyData = Data("{\"type\":\"excalidraw\",\"version\":2,\"source\":\"excalidays\",\"elements\":[],\"appState\":{\"viewBackgroundColor\":\"#ffffff\"},\"files\":{}}".utf8)

    let data: Data

    init(data: Data) throws {
        guard data.count <= Self.maximumByteCount else {
            throw DocumentError.sceneTooLarge
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DocumentError.invalidJSON
        }
        guard let root = object as? [String: Any] else {
            throw DocumentError.invalidJSON
        }
        guard root["type"] as? String == "excalidraw" else {
            throw DocumentError.unsupportedSceneType
        }
        guard root["elements"] is [Any] else {
            throw DocumentError.missingElements
        }
        self.data = data
    }
}
