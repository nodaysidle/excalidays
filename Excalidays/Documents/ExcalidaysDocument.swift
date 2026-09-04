import AppKit

private final class SceneDataStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Data

    init(_ data: Data) {
        storage = data
    }

    func read() -> Data {
        lock.withLock { storage }
    }

    func replace(with data: Data) {
        lock.withLock { storage = data }
    }
}

@MainActor
final class ExcalidaysDocument: NSDocument {
    nonisolated private let sceneStore = SceneDataStore(SceneEnvelope.emptyData)
    private var storedCanvasSession: CanvasSession?

    var canvasSession: CanvasSession {
        if let storedCanvasSession { return storedCanvasSession }
        let session = CanvasSession(initialSceneData: sceneStore.read())
        session.onDirty = { [weak self] in self?.updateChangeCount(.changeDone) }
        storedCanvasSession = session
        return session
    }

    override class var autosavesInPlace: Bool { true }
    override class var autosavesDrafts: Bool { true }
    override class var preservesVersions: Bool { true }

    override init() {
        super.init()
        hasUndoManager = false
    }

    override func makeWindowControllers() {
        addWindowController(DocumentWindowController(document: self))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        let envelope = try SceneEnvelope(data: data)
        sceneStore.replace(with: envelope.data)
    }

    override func data(ofType typeName: String) throws -> Data {
        try SceneEnvelope(data: sceneStore.read()).data
    }

    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        guard let storedCanvasSession, storedCanvasSession.runtimeState == .ready else {
            super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
            return
        }

        Task { [weak self] in
            guard let self else {
                completionHandler(DocumentError.canvasUnavailable)
                return
            }
            do {
                self.sceneStore.replace(with: try await storedCanvasSession.requestSnapshot())
                self.continueSaving(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
            } catch {
                completionHandler(error)
            }
        }
    }

    private func continueSaving(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
    }

    override func close() {
        storedCanvasSession?.destroy()
        super.close()
    }
}
