import WebKit
import XCTest
@testable import Excalidays

@MainActor
final class CanvasRuntimeIntegrationTests: XCTestCase {
    func testBundledRuntimePostsReadyEvent() async throws {
        let root = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("ExcalidrawCanvas", isDirectory: true))
        let index = root.appendingPathComponent("index.html")
        XCTAssertTrue(FileManager.default.fileExists(atPath: index.path))

        let handler = RuntimeReadyProbe()
        let navigation = NavigationProbe()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(CanvasAssetSchemeHandler(resourceRoot: root), forURLScheme: CanvasAssetSchemeHandler.scheme)
        configuration.userContentController.add(handler, name: "excalidays")
        let webView = WKWebView(frame: .init(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        webView.navigationDelegate = navigation
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 800, height: 600), styleMask: .titled, backing: .buffered, defer: false)
        window.contentView = webView

        webView.load(URLRequest(url: CanvasAssetSchemeHandler.indexURL))
        for _ in 0..<200 where !handler.receivedReady {
            try await Task.sleep(for: .milliseconds(50))
        }

        let diagnostics = try await webView.callAsyncJavaScript(
            """
            return JSON.stringify({
              secure: window.isSecureContext,
              randomUUID: typeof crypto.randomUUID,
              receive: typeof window.excalidaysReceive,
              rootChildren: document.getElementById('root')?.childElementCount ?? -1,
              bodyText: document.body.innerText.slice(0, 120)
            });
            """,
            arguments: [:],
            in: nil,
            contentWorld: .page
        ) as? String

        XCTAssertTrue(handler.receivedReady, diagnostics ?? "No runtime diagnostics")
        XCTAssertTrue(navigation.finished, navigation.errorDescription ?? "Navigation did not finish")
    }
}

@MainActor
private final class RuntimeReadyProbe: NSObject, WKScriptMessageHandler {
    private(set) var receivedReady = false

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let object = message.body as? [String: Any] else { return }
        receivedReady = object["operation"] as? String == "ready"
    }
}

@MainActor
private final class NavigationProbe: NSObject, WKNavigationDelegate {
    private(set) var finished = false
    private(set) var errorDescription: String?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finished = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        errorDescription = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        errorDescription = error.localizedDescription
    }
}
