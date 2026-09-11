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

    /// Finder double-click and drag-drop onto the app: one NSDocumentController open path
    /// (same as File → Open after the panel chooses a URL). Do not invent a second pipeline.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            coordinator.openDocument(at: url)
        }
    }

    // MARK: - Actions (menus + toolbar)

    @objc func newDrawing(_ sender: Any?) { coordinator.createNewDocumentAndPresentErrors() }
    @objc func openDrawing(_ sender: Any?) { coordinator.openDocument() }
    @objc func undoCanvas(_ sender: Any?) { currentDocument?.canvasSession.performCommand("undo") }
    @objc func redoCanvas(_ sender: Any?) { currentDocument?.canvasSession.performCommand("redo") }
    @objc func zoomToFitCanvas(_ sender: Any?) { currentDocument?.canvasSession.zoomToFit() }
    @objc func focusCanvas(_ sender: Any?) { currentDocument?.canvasSession.focusCanvas() }

    @objc func openHelpWebsite(_ sender: Any?) {
        guard let url = URL(string: "https://github.com/nodaysidle/excalidays#readme") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openGitHubIssues(_ sender: Any?) {
        guard let url = URL(string: "https://github.com/nodaysidle/excalidays/issues") else { return }
        NSWorkspace.shared.open(url)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undoCanvas(_:)) {
            return currentDocument?.canvasSession.canUndo == true
        }
        if menuItem.action == #selector(redoCanvas(_:)) {
            return currentDocument?.canvasSession.canRedo == true
        }
        if menuItem.action == #selector(zoomToFitCanvas(_:))
            || menuItem.action == #selector(focusCanvas(_:)) {
            return currentDocument != nil
        }
        return true
    }

    private var currentDocument: ExcalidaysDocument? {
        (NSDocumentController.shared.currentDocument ?? NSDocumentController.shared.documents.first) as? ExcalidaysDocument
    }

    // MARK: - Main menu (Phase 2 slice 2)

    private func installMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        installAppMenu(on: mainMenu)
        installFileMenu(on: mainMenu)
        installEditMenu(on: mainMenu)
        installViewMenu(on: mainMenu)
        installWindowMenu(on: mainMenu)
        installHelpMenu(on: mainMenu)
    }

    private func installAppMenu(on mainMenu: NSMenu) {
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "Excalidays")
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Excalidays", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        // No Preferences/Settings module in this slice — omit rather than ship a dead item.
        appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        appMenu.items.last?.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Excalidays", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Excalidays", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func installFileMenu(on mainMenu: NSMenu) {
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu

        let newDrawing = fileMenu.addItem(withTitle: "New Drawing", action: #selector(newDrawing(_:)), keyEquivalent: "n")
        newDrawing.target = self
        let openDrawing = fileMenu.addItem(withTitle: "Open…", action: #selector(openDrawing(_:)), keyEquivalent: "o")
        openDrawing.target = self

        let openRecent = fileMenu.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Open Recent")
        openRecent.submenu = recentMenu
        // NSDocumentController populates the Open Recent submenu automatically.

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
    }

    private func installEditMenu(on mainMenu: NSMenu) {
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
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    }

    private func installViewMenu(on mainMenu: NSMenu) {
        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu

        let zoomToFit = viewMenu.addItem(withTitle: "Zoom to Fit", action: #selector(zoomToFitCanvas(_:)), keyEquivalent: "0")
        zoomToFit.target = self
        let focus = viewMenu.addItem(withTitle: "Focus Canvas", action: #selector(focusCanvas(_:)), keyEquivalent: "")
        focus.target = self
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Show Toolbar", action: #selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Customize Toolbar…", action: #selector(NSWindow.runToolbarCustomizationPalette(_:)), keyEquivalent: "")
        viewMenu.addItem(.separator())
        let fullScreen = viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
    }

    private func installWindowMenu(on mainMenu: NSMenu) {
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

    private func installHelpMenu(on mainMenu: NSMenu) {
        let helpItem = NSMenuItem()
        mainMenu.addItem(helpItem)
        let helpMenu = NSMenu(title: "Help")
        helpItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu

        let help = helpMenu.addItem(withTitle: "Excalidays Help", action: #selector(openHelpWebsite(_:)), keyEquivalent: "?")
        help.target = self
        let issues = helpMenu.addItem(withTitle: "Report an Issue…", action: #selector(openGitHubIssues(_:)), keyEquivalent: "")
        issues.target = self
    }
}
