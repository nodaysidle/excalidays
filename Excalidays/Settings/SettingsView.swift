import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Privacy Glass Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Privacy & Security")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }

                    Text("Drawings stay entirely on this Mac. Excalidays has no account, telemetry, collaboration server, or cloud storage. The drawing canvas is a local, offline page with no server, and network access is present only inside the WebKit sandbox (see SECURITY.md).")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)

                // Canvas Gestures Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Canvas & Input")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }

                    Text("Trackpad pinch zooms the canvas, two-finger pan scrolls, and standard Apple keyboard shortcuts (⌘Z, ⇧⌘Z, ⌘S) control the canvas and document lifecycle.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            }
            .padding(24)
        }
        .frame(width: 480, height: 280)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "Excalidays Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.center()
    }
}
