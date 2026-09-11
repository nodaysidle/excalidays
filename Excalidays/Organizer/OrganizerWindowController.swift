import AppKit
import SwiftUI

@MainActor
final class OrganizerWindowController: NSWindowController {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        let root = OrganizerView { url, stopAccess in
            coordinator.openDocument(at: url) { _ in
                stopAccess()
            }
        }
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Organizer"
        window.setContentSize(NSSize(width: 860, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func showOrganizer() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
