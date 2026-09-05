import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSDocumentController.shared.autosavingDelay = 30
        installMainMenu()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        coordinator.createNewDocumentAndPresentErrors()
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            coordinator.createNewDocumentAndPresentErrors()
        }
        return true
    }

    @objc private func newDrawing(_ sender: Any?) { coordinator.createNewDocumentAndPresentErrors() }
    @objc private func openDrawing(_ sender: Any?) { coordinator.openDocument() }
    @objc private func undoCanvas(_ sender: Any?) { currentDocument?.canvasSession.performCommand("undo") }
    @objc private func redoCanvas(_ sender: Any?) { currentDocument?.canvasSession.performCommand("redo") }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undoCanvas(_:)) {
            return currentDocument?.canvasSession.canUndo == true
        }
        if menuItem.action == #selector(redoCanvas(_:)) {
            return currentDocument?.canvasSession.canRedo == true
        }
        return true
    }

    private var currentDocument: ExcalidaysDocument? {
        (NSDocumentController.shared.currentDocument ?? NSDocumentController.shared.documents.first) as? ExcalidaysDocument
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "Excalidays")
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Excalidays", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Excalidays", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Excalidays", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        let newDrawing = fileMenu.addItem(withTitle: "New Drawing", action: #selector(newDrawing(_:)), keyEquivalent: "n")
        newDrawing.target = self
        let openDrawing = fileMenu.addItem(withTitle: "Open…", action: #selector(openDrawing(_:)), keyEquivalent: "o")
        openDrawing.target = self
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "Save", action: Selector(("saveDocument:")), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Save As…", action: Selector(("saveDocumentAs:")), keyEquivalent: "S")
        fileMenu.addItem(withTitle: "Duplicate", action: Selector(("duplicateDocument:")), keyEquivalent: "D")
        fileMenu.addItem(withTitle: "Rename…", action: Selector(("renameDocument:")), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Move To…", action: Selector(("moveDocument:")), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Revert to Saved", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Browse All Versions…", action: #selector(NSDocument.browseVersions(_:)), keyEquivalent: "")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Print…", action: #selector(NSDocument.printDocument(_:)), keyEquivalent: "p")

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        let undo = editMenu.addItem(withTitle: "Undo", action: #selector(undoCanvas(_:)), keyEquivalent: "z")
        undo.target = self
        let redo = editMenu.addItem(withTitle: "Redo", action: #selector(redoCanvas(_:)), keyEquivalent: "Z")
        redo.target = self
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
    }
}
