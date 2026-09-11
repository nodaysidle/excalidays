import AppKit

@MainActor
final class AppCoordinator {
    @discardableResult
    func createNewDocument() throws -> ExcalidaysDocument {
        let controller = NSDocumentController.shared
        let document = try controller.makeUntitledDocument(ofType: "com.excalidraw.excalidraw")
        guard let document = document as? ExcalidaysDocument else {
            throw DocumentError.unsupportedSceneType
        }
        controller.addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
        return document
    }

    func createNewDocumentAndPresentErrors() {
        do {
            try createNewDocument()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// File → Open… — standard NSDocumentController open panel.
    func openDocument() {
        NSDocumentController.shared.openDocument(nil)
    }

    /// Finder double-click / drag-drop onto the app icon.
    /// Same NSDocumentController pipeline as File → Open (no parallel open path).
    func openDocument(at url: URL, display: Bool = true, completionHandler: ((Error?) -> Void)? = nil) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: display) { _, _, error in
            if let error {
                NSAlert(error: error).runModal()
            }
            completionHandler?(error)
        }
    }
}
