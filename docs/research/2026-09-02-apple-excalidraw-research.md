# Apple and Excalidraw primary-source research — 2026-09-02

Access date: 2026-09-02. Sources are Apple Developer Documentation, official Excalidraw docs/repository, and npm registry metadata.

| Source | URL | Relevant API/fact | Design consequence | Uncertainty |
|---|---|---|---|---|
| NSDocument | https://developer.apple.com/documentation/appkit/nsdocument | MainActor document owns data/windows/edited state/save/revert/print; safe saves may use unrelated temporary URLs | Real subclass; invoke save/revert APIs and never assume write URL equals fileURL | Async canvas snapshots must be staged before synchronous write primitive |
| NSDocumentController | https://developer.apple.com/documentation/appkit/nsdocumentcontroller | New/Open/Recent, concurrent documents, Info.plist mappings, autosaving delay | Shared native lifecycle and Finder opening | Window-restoration edge cases need runtime tests |
| NSWindowController | https://developer.apple.com/documentation/appkit/nswindowcontroller | Document window ownership and lifecycle | One controller per document window | Full page extraction was unavailable to delegate |
| autosavesInPlace | https://developer.apple.com/documentation/appkit/nsdocument/autosavesinplace | Opt-in in-place autosave | Override true | WKWebView snapshot timing needs integration proof |
| browseVersions(_:) | https://developer.apple.com/documentation/appkit/nsdocument/browseversions(_:) | Native Browse All Versions | Use native File > Revert To plus in-app history | None |
| Defining file and data types | https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app | Imported/exported declarations, reverse DNS, JSON/content/data conformance | Import `com.excalidraw.excalidraw` pending official canonical UTI | No canonical UTI found is absence of evidence, not registry proof |
| App Sandbox | https://developer.apple.com/documentation/security/app-sandbox | User-selected read/write entitlement | Sandbox with no network entitlement | Finder/recent behavior needs packaged test |
| Accessing files from App Sandbox | https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox | Panels extend access; security-scoped bookmark lifecycle | Persist approved file/folder access and balance start/stop | Stale/moved recovery needs tests |
| WKWebView | https://developer.apple.com/documentation/webkit/wkwebview | Local loading, configuration, navigation/UI delegates, async JS | Bundle-local canvas and strict delegates | File-origin font behavior needs packaged test |
| WKScriptMessageHandlerWithReply | https://developer.apple.com/documentation/webkit/wkscriptmessagehandlerwithreply | JS messages with native replies | Typed request/reply bridge | Large payload performance must be measured |
| WKContentWorld | https://developer.apple.com/documentation/webkit/wkcontentworld | Script namespaces | Named app bridge world plus narrow page adapter | Excalidraw API remains in page world |
| WKUserContentController | https://developer.apple.com/documentation/webkit/wkusercontentcontroller | Handler install/remove and filters | Explicit teardown | None for Phase 1 |
| WKNavigationDelegate | https://developer.apple.com/documentation/webkit/wknavigationdelegate | Allow/reject navigation and responses | Initial local file only; reject remote/new/download | CSP/content rules also required for subresources |
| PDFKit | https://developer.apple.com/documentation/pdfkit | PDFDocument/PDFPage/PDFThumbnailView | Native PDF validation/page selection/rendering | Encrypted/malformed fixtures required |
| Core Graphics beginPDFPage | https://developer.apple.com/documentation/coregraphics/cgcontext/beginpdfpage(_:) | Vector PDF page generation | Candidate vector export path | Exact Excalidraw SVG-to-CG fidelity needs spike |
| SwiftData | https://developer.apple.com/documentation/swiftdata | Model container/context/query | Catalog/bookmarks/settings/history indexes only | Migration plan required before release |
| Accessibility for AppKit | https://developer.apple.com/documentation/appkit/accessibility-for-appkit | Accessibility roles/protocols/elements | Native shell labels/focus/roles | WKWebView canvas accessibility remains separate |
| NSEvent | https://developer.apple.com/documentation/appkit/nsevent | Precise deltas, momentum, magnification, button/click data | Preserve standard responder/WebKit input; no global tap | Physical middle-button and device feel need manual test |
| npm latest metadata | https://registry.npmjs.org/@excalidraw/excalidraw/latest | Stable 0.18.1, MIT; React/DOM peer `^17.0.2 || ^18.2.0 || ^19.0.0` | Exact pin and lockfile | Publish timestamp is operational metadata |
| Installation | https://docs.excalidraw.com/docs/@excalidraw/excalidraw/installation | ESM component, CSS/nonzero dimensions, fonts default to CDN unless self-hosted | Vite bundle; copy prod fonts and set local asset path | Packaged no-network test mandatory |
| Published 0.18.1 types | https://cdn.jsdelivr.net/npm/@excalidraw/excalidraw@0.18.1/dist/types/excalidraw/types.d.ts | Stable `excalidrawAPI`; imperative update/get/files/history/scroll/active-tool and subscriptions | Code to installed declarations | Master docs are ahead of release |
| API utils | https://docs.excalidraw.com/docs/@excalidraw/excalidraw/api/utils | serializeAsJSON, loadFromBlob, restore helpers | Official runtime remains authority | Serialization strips fields; explicit compatible-field merge needed |
| Export utilities | https://docs.excalidraw.com/docs/@excalidraw/excalidraw/api/utils/export | exportToBlob/Svg/Clipboard and `exportEmbedScene` | Editable vs plain PNG/SVG | Export APIs announced for rewrite |
| Official blob implementation | https://github.com/excalidraw/excalidraw/blob/master/packages/excalidraw/data/blob.ts | loadSceneOrLibraryFromBlob decodes embedded PNG/SVG metadata | Use official helper for editable detection | Master/release drift must be checked against installed package |
| Excalidraw LICENSE | https://raw.githubusercontent.com/excalidraw/excalidraw/master/LICENSE | MIT, Copyright 2020 Excalidraw | Bundle notice | Complete per-font/transitive notices still need inventory |

## Exact dependency decision
Pin `@excalidraw/excalidraw` 0.18.1. Use exact React/ReactDOM versions compatible with that peer range and exact TypeScript/Vite/Vitest versions in the lockfile. Installed declarations override master-only APIs such as `onExcalidrawAPI`, `ui`, `interaction`, `setViewport`, and `imageOptions`.

## UTI decision
Apple documentation contains no Excalidraw UTI. Excalidays does not own the Excalidraw format, so it declares an imported namespaced type `com.excalidraw.excalidraw` for `.excalidraw`, conforming to JSON/content/data. Revisit if Excalidraw publishes a canonical identifier.
