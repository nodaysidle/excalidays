import Foundation

struct CanvasURLPolicy: Sendable {
    private let resourceRoot: URL
    private let allowedPathPrefix: String

    init(resourceRoot: URL) {
        self.resourceRoot = resourceRoot.standardizedFileURL
        self.allowedPathPrefix = self.resourceRoot.path.hasSuffix("/") ? self.resourceRoot.path : self.resourceRoot.path + "/"
    }

    func allows(_ url: URL) -> Bool {
        if url.scheme == CanvasAssetSchemeHandler.scheme {
            return url.host == CanvasAssetSchemeHandler.host
        }
        guard url.isFileURL else { return false }
        let candidate = url.standardizedFileURL
        return candidate == resourceRoot || candidate.path.hasPrefix(allowedPathPrefix)
    }
}
