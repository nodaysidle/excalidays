# Excalidays Technical Requirements

**Authority:** 3 of 5. PRD.md and ARD.md override this file; this file overrides TASKS.md and AGENTS.md.

## Toolchain and dependencies
- Xcode 26.6 (17F113), Swift compiler 6.3.3, Swift language mode 6, complete strict concurrency.
- Deployment target macOS 14.0.
- `@excalidraw/excalidraw` 0.18.1; React and React DOM exact compatible pins.
- TypeScript, Vite, and Vitest exact pins recorded in `package-lock.json`.
- No remote runtime dependency after build.

## Document type
Use imported UTI `com.excalidraw.excalidraw`, extension `excalidraw`, conforming to `public.json`, `public.content`, and `public.data`. Official Apple/Excalidraw sources reviewed expose no canonical UTI. Excalidays does not own the format, so an imported declaration is more accurate than exporting a proprietary type. `CFBundleDocumentTypes` maps it to `ExcalidaysDocument` with Editor role.

## Scene envelope
A scene is bounded UTF-8 JSON with root object, `type: "excalidraw"`, elements array, optional appState object, optional files object, and compatible unknown fields. Swift validates only root/type/size and retains bytes. Runtime uses official `loadFromBlob`/restore and `serializeAsJSON`; files come from `getFiles()` and are included in the saved scene.

## Bridge v1
Envelope fields: `protocolVersion: 1`, `id`, `kind`, `operation`, `payload`, optional `error`.

Native operations: `initialize`, `loadScene`, `requestSnapshot`, `updateTheme`, `performCommand`, `importBinaryFile`, `exportScene`, `zoomToFit`, `zoomToSelection`, `setReadOnly`, `focusCanvas`.

Runtime events: `ready`, `dirtyStateChanged`, `selectionChanged`, `documentMetadataChanged`, `commandStateChanged`, `runtimeError`.

Rules: reject unknown versions/kinds/operations; preserve IDs; default timeout 10 seconds; maximum scene payload 64 MiB and event payload 64 KiB; no file paths; no arbitrary method execution.

## Stable Excalidraw 0.18.1 contract
Use published `excalidrawAPI`, not master-only `onExcalidrawAPI`. Use stable `updateScene`, `addFiles`, `getSceneElementsIncludingDeleted`, `getAppState`, `getFiles`, `history`, `scrollToContent`, `setActiveTool`, and subscriptions. Do not use unreleased `ui`, `interaction`, `setViewport`, `imageOptions`, or lifecycle APIs. Browser-owned actions are disabled through stable `UIOptions.canvasActions` and supported children configuration.

## Runtime behavior
- Import package CSS and self-host `dist/prod/fonts`; set local `EXCALIDRAW_ASSET_PATH` before module load.
- Hide native-owned file/save/export/share/collaboration/library shell actions while retaining drawing tools.
- `onChange` emits dirty only on clean-to-dirty transition, never full JSON per pointer movement.
- Snapshot uses current elements/appState/files and merges compatible unknown top-level fields.
- Native undo/redo invokes canvas commands; no second Swift element-history stack.

## NSDocument
`ExcalidaysDocument` is `@MainActor`, supports in-place autosave and native versions, retains scene data, owns a canvas session, creates a document window controller, validates bounded input, stages explicit runtime snapshots before native save, and updates change count from dirty events. Untitled documents use a legal empty scene.

## Canvas security
Load only bundle-local canvas resources. CSP: `default-src 'none'`; required local script/style/font/image/blob/data only; `connect-src 'none'`; `frame-src 'none'`; `object-src 'none'`; `base-uri 'none'`. Deny navigation/new windows/downloads. Use a nonpersistent website data store. localStorage is never canonical.

## Limits
- Scene JSON: 64 MiB.
- Image compressed: 100 MiB; 16,384 px per side; 100 MP decoded.
- SVG: 32 MiB; no scripts or external resources.
- PDF: 500 MiB, 500 pages, 200 MP selected render budget.

## Test contracts
TypeScript: bridge validation, request/reply, mismatch, dirty coalescing, snapshot attachments/unknowns, destroyed guard, CSP/no network. XCTest: format sniffing, envelope validation, unknown preservation, atomic writer failure, UTI declarations, Codable mismatch. Integration/manual: native menu routing, save/reopen, organizer keyboard flow, multiwindow, physical pointer matrix, VoiceOver, package launch.

## Canonical commands
`Scripts/bootstrap.sh`, `Scripts/build_canvas.sh`, `Scripts/build_app.sh`, `Scripts/test_all.sh`, `Scripts/package_app.sh`, and `Scripts/verify_app.sh` are the build interface.
