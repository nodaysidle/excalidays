import AppKit
import SwiftUI

@MainActor
final class DocumentWindowController: NSWindowController, NSToolbarDelegate {
    private static let zoomToFitIdentifier = NSToolbarItem.Identifier("com.nodaysidle.excalidays.zoomToFit")
    private static let focusCanvasIdentifier = NSToolbarItem.Identifier("com.nodaysidle.excalidays.focusCanvas")

    private let canvasSession: CanvasSession

    init(document: ExcalidaysDocument) {
        self.canvasSession = document.canvasSession
        let content = NSHostingController(rootView: DocumentContentView(session: document.canvasSession))
        let window = NSWindow(contentViewController: content)
        window.title = document.displayName
        window.setContentSize(NSSize(width: 1120, height: 760))
        window.minSize = NSSize(width: 680, height: 480)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = false
        window.tabbingMode = .preferred
        super.init(window: window)

        let toolbar = NSToolbar(identifier: "ExcalidaysDocumentToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window.toolbar = toolbar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.zoomToFitIdentifier, Self.focusCanvasIdentifier]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.zoomToFitIdentifier, Self.focusCanvasIdentifier]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.zoomToFitIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Zoom to Fit"
            item.paletteLabel = "Zoom to Fit"
            item.toolTip = "Fit the drawing in the window"
            item.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Zoom to Fit")
            item.target = self
            item.action = #selector(zoomToFit(_:))
            return item
        case Self.focusCanvasIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Focus Canvas"
            item.paletteLabel = "Focus Canvas"
            item.toolTip = "Move keyboard focus to the drawing canvas"
            item.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Focus Canvas")
            item.target = self
            item.action = #selector(focusCanvas(_:))
            return item
        default:
            return nil
        }
    }

    @objc private func zoomToFit(_ sender: Any?) { canvasSession.zoomToFit() }
    @objc private func focusCanvas(_ sender: Any?) { canvasSession.focusCanvas() }
}
