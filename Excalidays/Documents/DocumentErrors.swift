import Foundation

enum DocumentError: Error, Equatable, LocalizedError {
    case sceneTooLarge
    case invalidJSON
    case unsupportedSceneType
    case missingElements
    case canvasUnavailable
    case invalidSnapshot

    var errorDescription: String? {
        switch self {
        case .sceneTooLarge: "The drawing is larger than the 64 MB safety limit."
        case .invalidJSON: "The file does not contain valid JSON."
        case .unsupportedSceneType: "The file is not an Excalidraw drawing."
        case .missingElements: "The Excalidraw drawing has no elements array."
        case .canvasUnavailable: "The drawing canvas is not ready."
        case .invalidSnapshot: "The canvas returned an invalid drawing snapshot."
        }
    }
}
