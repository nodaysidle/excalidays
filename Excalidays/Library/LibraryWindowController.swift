import AppKit
import SwiftUI

@MainActor
final class LibraryWindowController: NSWindowController {
    convenience init(createNewDrawing: @escaping () -> Void, openDrawing: @escaping () -> Void) {
        let hostingController = NSHostingController(
            rootView: LibraryView(createNewDrawing: createNewDrawing, openDrawing: openDrawing)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Excalidays Library"
        window.setContentSize(NSSize(width: 900, height: 580))
        window.minSize = NSSize(width: 720, height: 460)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.center()
    }
}
