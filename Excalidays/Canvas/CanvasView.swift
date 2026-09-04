import SwiftUI
import WebKit

struct CanvasView: NSViewRepresentable {
    let session: CanvasSession

    func makeNSView(context: Context) -> WKWebView {
        session.makeWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Void) {
        nsView.stopLoading()
    }
}
