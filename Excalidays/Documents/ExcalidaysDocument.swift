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
    private var canvasDirty = false

    var canvasSession: CanvasSession {
        if let storedCanvasSession { return storedCanvasSession }
        let session = CanvasSession(initialSceneData: sceneStore.read())
        session.onDirtyStateChanged = { [weak self] isDirty in
            guard let self else { return }
            guard isDirty != self.canvasDirty else { return }
            self.canvasDirty = isDirty
            self.updateChangeCount(isDirty ? .changeDone : .changeCleared)
        }
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
        // read(from:) overrides the nonisolated NSDocument method, but AppKit
        // always calls it on the main thread; run the MainActor state here
        // synchronously so we only reload an *existing* session (revert-to-saved),
        // never the initial open (session still nil at read time).
        MainActor.assumeIsolated {
            self.canvasDirty = false
            guard let session = self.storedCanvasSession else { return }
            let revertedScene = envelope.data
            Task { [weak session] in
                guard let session else { return }
                _ = try? await session.reloadScene(with: revertedScene)
            }
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        try SceneEnvelope(data: sceneStore.read()).data
    }

    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        guard let storedCanvasSession else {
            super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
            return
        }
        switch storedCanvasSession.runtimeState {
        case .ready:
            saveCanvasSnapshot(from: storedCanvasSession, to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
        case .loading:
            Task { [weak self] in
                guard let self else {
                    completionHandler(DocumentError.canvasUnavailable)
                    return
                }
                do {
                    try await self.waitForCanvasReady(storedCanvasSession)
                    self.saveCanvasSnapshot(from: storedCanvasSession, to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
                } catch {
                    completionHandler(error)
                }
            }
        case .failed, .destroyed:
            completionHandler(DocumentError.canvasUnavailable)
        }
    }

    private static let canvasReadinessTimeout: Duration = .seconds(10)

    private func waitForCanvasReady(_ session: CanvasSession) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.canvasReadinessTimeout)
        while clock.now < deadline {
            switch session.runtimeState {
            case .ready:
                return
            case .failed, .destroyed:
                throw DocumentError.canvasUnavailable
            case .loading:
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        throw DocumentError.canvasUnavailable
    }

    private func saveCanvasSnapshot(from session: CanvasSession, to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        Task { [weak self] in
            guard let self else {
                completionHandler(DocumentError.canvasUnavailable)
                return
            }
            do {
                self.sceneStore.replace(with: try await session.requestSnapshot())
                self.canvasDirty = false
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
