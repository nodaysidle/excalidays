import AppKit
import SwiftUI

@MainActor
final class DocumentWindowController: NSWindowController, NSToolbarDelegate {
    private static let newDrawingIdentifier = NSToolbarItem.Identifier("com.nodaysidle.excalidays.newDrawing")
    private static let openDrawingIdentifier = NSToolbarItem.Identifier("com.nodaysidle.excalidays.openDrawing")
    private static let zoomToFitIdentifier = NSToolbarItem.Identifier("com.nodaysidle.excalidays.zoomToFit")
    private static let focusCanvasIdentifier = NSToolbarItem.Identifier("com.nodaysidle.excalidays.focusCanvas")

    /// Slice 2 toolbar: document actions + canvas focus/fit. No Organizer/Settings chrome.
    private static let toolbarItemIdentifiers: [NSToolbarItem.Identifier] = [
        newDrawingIdentifier,
        openDrawingIdentifier,
        .flexibleSpace,
        zoomToFitIdentifier,
        focusCanvasIdentifier,
    ]

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
        Self.toolbarItemIdentifiers + [.space, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolbarItemIdentifiers
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.newDrawingIdentifier:
            return makeItem(
                itemIdentifier,
                label: "New Drawing",
                toolTip: "Create a new drawing",
                symbol: "doc.badge.plus",
                action: #selector(newDrawing(_:))
            )
        case Self.openDrawingIdentifier:
            return makeItem(
                itemIdentifier,
                label: "Open",
                toolTip: "Open an existing drawing",
                symbol: "folder",
                action: #selector(openDrawing(_:))
            )
        case Self.zoomToFitIdentifier:
            return makeItem(
                itemIdentifier,
                label: "Zoom to Fit",
                toolTip: "Fit the drawing in the window",
                symbol: "arrow.up.left.and.arrow.down.right",
                action: #selector(zoomToFit(_:))
            )
        case Self.focusCanvasIdentifier:
            return makeItem(
                itemIdentifier,
                label: "Focus Canvas",
                toolTip: "Move keyboard focus to the drawing canvas",
                symbol: "scope",
                action: #selector(focusCanvas(_:))
            )
        default:
            return nil
        }
    }

    private func makeItem(
        _ itemIdentifier: NSToolbarItem.Identifier,
        label: String,
        toolTip: String,
        symbol: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = toolTip
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.target = self
        item.action = action
        return item
    }

    @objc private func newDrawing(_ sender: Any?) {
        NSApp.sendAction(#selector(AppDelegate.newDrawing(_:)), to: nil, from: sender)
    }

    @objc private func openDrawing(_ sender: Any?) {
        NSApp.sendAction(#selector(AppDelegate.openDrawing(_:)), to: nil, from: sender)
    }

    @objc private func zoomToFit(_ sender: Any?) { canvasSession.zoomToFit() }
    @objc private func focusCanvas(_ sender: Any?) { canvasSession.focusCanvas() }
}
