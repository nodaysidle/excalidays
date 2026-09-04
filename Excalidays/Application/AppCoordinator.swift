import AppKit

@MainActor
final class AppCoordinator {
    private var libraryWindowController: LibraryWindowController?
    private var settingsWindowController: SettingsWindowController?

    func showLibrary() {
        if libraryWindowController == nil {
            libraryWindowController = LibraryWindowController(
                createNewDrawing: { [weak self] in
                    self?.createNewDocumentAndPresentErrors()
                    self?.libraryWindowController?.close()
                },
                openDrawing: { [weak self] in
                    self?.openDocument()
                    self?.libraryWindowController?.close()
                }
            )
        }
        libraryWindowController?.showWindow(nil)
        libraryWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

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
