import AppKit
import SwiftUI

@MainActor
final class OrganizerWindowController: NSWindowController {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        let store = OrganizerStore.shared
        let root = OrganizerView(
            onOpen: { url in
                coordinator.openDocument(at: url)
            },
            onRefresh: {
                (try? store.fetchRecents()) ?? []
            },
            onRemove: { recent in
                store.remove(recent)
            }
        )
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Organizer"
        window.setContentSize(NSSize(width: 480, height: 520))
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
