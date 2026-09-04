@preconcurrency import WebKit
import Foundation
import UniformTypeIdentifiers

final class CanvasAssetSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    nonisolated static let scheme = "excalidays"
    nonisolated static let host = "canvas"
    nonisolated static let indexURL = URL(string: "excalidays://canvas/index.html")!

    private let resourceRoot: URL
    private let policy: CanvasURLPolicy

    init(resourceRoot: URL) {
        self.resourceRoot = resourceRoot.standardizedFileURL
        self.policy = CanvasURLPolicy(resourceRoot: resourceRoot)
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        do {
            let (fileURL, mimeType) = try resolve(urlSchemeTask.request.url)
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            let response = URLResponse(
                url: try requireURL(urlSchemeTask.request.url),
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: isText(mimeType) ? "utf-8" : nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private func resolve(_ url: URL?) throws -> (URL, String) {
        let url = try requireURL(url)
        guard url.scheme == Self.scheme, url.host == Self.host else {
            throw URLError(.unsupportedURL)
        }

        let decodedPath = url.path.removingPercentEncoding ?? url.path
        let relativePath = decodedPath == "/" ? "index.html" : String(decodedPath.drop(while: { $0 == "/" }))
        guard !relativePath.isEmpty,
              !relativePath.split(separator: "/").contains("..") else {
            throw URLError(.noPermissionsToReadFile)
        }

        let fileURL = resourceRoot.appendingPathComponent(relativePath).standardizedFileURL
        guard policy.allows(fileURL) else {
            throw URLError(.noPermissionsToReadFile)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw URLError(.fileDoesNotExist)
        }

        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return (fileURL, mimeType)
    }

    private func requireURL(_ url: URL?) throws -> URL {
        guard let url else { throw URLError(.badURL) }
        return url
    }

    private func isText(_ mimeType: String) -> Bool {
        mimeType.hasPrefix("text/") || mimeType == "application/javascript" || mimeType == "application/json"
    }
}
