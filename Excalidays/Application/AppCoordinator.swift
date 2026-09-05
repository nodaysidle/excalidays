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

    func openDocument() {
        NSDocumentController.shared.openDocument(nil)
    }
}
