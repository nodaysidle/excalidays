import Foundation

struct CanvasBridgeError: Error, LocalizedError, Sendable {
    let message: String

    var errorDescription: String? { message }
}
