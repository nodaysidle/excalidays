@preconcurrency import WebKit
import Foundation
import Observation

@MainActor
@Observable
final class CanvasSession {
    enum RuntimeState: Equatable {
        case loading
        case ready
        case failed(String)
        case destroyed
    }

    private(set) var runtimeState: RuntimeState = .loading
    var onDirty: (() -> Void)?

    private var sceneData: Data
    private var webView: WKWebView?
    private var messageHandler: CanvasMessageHandler?
    private var navigationCoordinator: CanvasNavigationCoordinator?
    private var assetSchemeHandler: CanvasAssetSchemeHandler?

    init(initialSceneData: Data) {
        self.sceneData = initialSceneData
    }

    func makeWebView() -> WKWebView {
        if let webView { return webView }

        guard let runtimeRoot = Bundle.main.resourceURL?.appendingPathComponent("ExcalidrawCanvas", isDirectory: true) else {
            runtimeState = .failed("The local canvas resource directory is missing.")
            return WKWebView(frame: .zero)
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.suppressesIncrementalRendering = false

        let assetSchemeHandler = CanvasAssetSchemeHandler(resourceRoot: runtimeRoot)
        configuration.setURLSchemeHandler(assetSchemeHandler, forURLScheme: CanvasAssetSchemeHandler.scheme)
        let handler = CanvasMessageHandler(session: self)
        configuration.userContentController.add(handler, name: "excalidays")

        let coordinator = CanvasNavigationCoordinator(policy: CanvasURLPolicy(resourceRoot: runtimeRoot), session: self)
        let created = WKWebView(frame: .zero, configuration: configuration)
        created.navigationDelegate = coordinator
        created.uiDelegate = coordinator
        created.allowsBackForwardNavigationGestures = false
        created.allowsMagnification = true
        created.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.3, *) {
            created.isInspectable = true
        }

        self.messageHandler = handler
        self.navigationCoordinator = coordinator
        self.assetSchemeHandler = assetSchemeHandler
        self.webView = created

        let indexURL = runtimeRoot.appendingPathComponent("index.html")
        if FileManager.default.fileExists(atPath: indexURL.path) {
            created.load(URLRequest(url: CanvasAssetSchemeHandler.indexURL))
        } else {
            runtimeState = .failed("The bundled canvas index is missing.")
        }
        return created
    }

    func handleEvent(_ body: Any) {
        guard runtimeState != .destroyed,
              JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body),
              let message = try? CanvasBridgeMessage.decode(data, maximumByteCount: CanvasBridgeMessage.maximumEventByteCount),
              message.kind == .event else { return }

        switch message.operation {
        case .ready:
            runtimeState = .ready
            Task { [weak self] in
                guard let self else { return }
                do { try await self.loadScene(self.sceneData, operation: .initialize) }
                catch { self.runtimeState = .failed(error.localizedDescription) }
            }
        case .dirtyStateChanged:
            onDirty?()
        case .runtimeError:
            let text: String
            if case let .object(payload) = message.payload,
               case let .string(value)? = payload["message"] {
                text = value
            } else {
                text = "Canvas runtime error"
            }
            runtimeState = .failed(text)
        default:
            break
        }
    }

    func loadScene(_ data: Data, operation: CanvasBridgeOperation = .loadScene) async throws {
        _ = try SceneEnvelope(data: data)
        guard let sceneJSON = String(data: data, encoding: .utf8) else { throw DocumentError.invalidJSON }
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        _ = try await send(operation: operation, payload: [
            "sceneJSON": sceneJSON,
            "theme": isDark ? "dark" : "light"
        ])
        sceneData = data
    }

    func requestSnapshot() async throws -> Data {
        let response = try await send(operation: .requestSnapshot)
        guard let payload = response["payload"] as? [String: Any],
              let sceneJSON = payload["sceneJSON"] as? String,
              let data = sceneJSON.data(using: .utf8) else {
            throw DocumentError.invalidSnapshot
        }
        _ = try SceneEnvelope(data: data)
        sceneData = data
        return data
    }

    func performCommand(_ command: String) {
        Task { [weak self] in
            _ = try? await self?.send(operation: .performCommand, payload: ["command": command])
        }
    }

    func zoomToFit() {
        Task { [weak self] in _ = try? await self?.send(operation: .zoomToFit) }
    }

    func focusCanvas() {
        webView?.window?.makeFirstResponder(webView)
        Task { [weak self] in _ = try? await self?.send(operation: .focusCanvas) }
    }

    func destroy() {
        guard runtimeState != .destroyed else { return }
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "excalidays", contentWorld: .page)
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
        messageHandler = nil
        navigationCoordinator = nil
        assetSchemeHandler = nil
        onDirty = nil
        runtimeState = .destroyed
    }

    private func send(operation: CanvasBridgeOperation, payload: [String: Any] = [:]) async throws -> [String: Any] {
        guard runtimeState != .destroyed, let webView else { throw DocumentError.canvasUnavailable }
        let request: [String: Any] = [
            "protocolVersion": CanvasBridgeMessage.protocolVersion,
            "id": UUID().uuidString,
            "kind": CanvasBridgeKind.request.rawValue,
            "operation": operation.rawValue,
            "payload": payload,
        ]
        let result = try await webView.callAsyncJavaScript(
            "return await window.excalidaysReceive(request);",
            arguments: ["request": request],
            in: nil,
            contentWorld: .page
        )
        guard let response = result as? [String: Any],
              response["protocolVersion"] as? Int == CanvasBridgeMessage.protocolVersion,
              response["kind"] as? String == CanvasBridgeKind.response.rawValue else {
            throw CanvasBridgeError(message: "Canvas returned an invalid bridge response.")
        }
        if let error = response["error"] as? [String: Any] {
            throw CanvasBridgeError(message: error["message"] as? String ?? "Canvas operation failed.")
        }
        return response
    }

    func reportError(_ message: String) {
        guard runtimeState != .destroyed else { return }
        runtimeState = .failed(message)
    }

    func reportCrash() {
        guard runtimeState != .destroyed else { return }
        runtimeState = .failed("Canvas process terminated unexpectedly.")
    }
}

@MainActor
private final class CanvasMessageHandler: NSObject, WKScriptMessageHandler {
    weak var session: CanvasSession?

    init(session: CanvasSession) {
        self.session = session
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        session?.handleEvent(message.body)
    }
}

@MainActor
private final class CanvasNavigationCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    private let policy: CanvasURLPolicy
    private weak var session: CanvasSession?

    init(policy: CanvasURLPolicy, session: CanvasSession) {
        self.policy = policy
        self.session = session
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, policy.allows(url) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        session?.reportError("Navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        session?.reportError("Provisional navigation failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        session?.reportCrash()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        nil
    }
}
