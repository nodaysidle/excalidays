# Excalidays Architecture Requirements

**Authority:** 2 of 5. PRD.md overrides this file; this file overrides TRD.md, TASKS.md, and AGENTS.md.

## Architecture decision
Use Swift 6 strict concurrency, AppKit document architecture, SwiftUI native surfaces, focused AppKit integration, SwiftData metadata, PDFKit/Core Graphics, UniformTypeIdentifiers, and one offline `WKWebView` canvas per open document.

## Deployment target
macOS 14.0. It is the oldest release supporting SwiftData and the approved modern SwiftUI baseline. The installed Xcode 26.6 / Swift 6.3.3 toolchain exceeds the Swift 6.2 floor; source uses Swift 6 language mode and complete strict concurrency.

## Native process owns
- Application lifecycle and activation.
- `NSDocumentController`, `NSDocument`, `NSWindowController`, edited state, saves, autosave, revert, close review, and multiwindow behavior.
- Library, catalog, workspaces, security-scoped bookmarks, history, thumbnails, native commands, Settings, imports/exports, printing, and packaging.
- File coordination, safe writes, input bounds, diagnostics, and local-only policy.

## Canvas runtime owns
- Excalidraw rendering, drawing tools, element semantics, and canvas interaction.
- Canvas-local undo/redo.
- Official restore/serialization and attachment handling.
- Official scene/image/SVG export and embedded-scene helpers.

## Forbidden coupling
No browser application shell, web file dialogs, collaboration/share controls, remote library, localStorage authority, arbitrary JavaScript dispatch, raw filesystem paths in JavaScript, or full-scene transfer per pointer movement. Swift does not rigidly decode/re-encode the complete scene.

## Data flow
1. `NSDocument.read` accepts bounded bytes and retains compatible JSON.
2. A document window creates one `CanvasSession` and secure web view.
3. Runtime loads local `index.html`, announces readiness, then receives protocol-v1 initialization/load.
4. `onChange` emits lightweight dirty/metadata events.
5. Save/autosave/history/export explicitly requests a snapshot.
6. AppKit safe-save writes the snapshot; history later stores immutable objects under Application Support.

## Bridge
Codable Swift envelopes and TypeScript discriminated unions carry protocol version, request ID, allowlisted operation, bounded payload, response, or structured error. Default request timeout is 10 seconds; export gets 30 seconds. Handlers and pending requests are removed on close.

## WebKit security
Only bundle resources under the canvas directory load. Navigation, new windows, downloads, redirects, HTTP(S), WebSocket, and arbitrary schemes are denied. CSP allows only required local script/style/font/image/blob/data sources. The app has no network entitlement.

## Persistence
- Canonical drawing: user-owned file.
- Catalog/settings/bookmarks/history index: SwiftData under Application Support.
- History: immutable content-addressed scene/attachment objects with atomic manifests.
- Temporary imports/exports: app cache/temp, deterministically cleaned.

## Native design language
**Desk + Folio:** the Library is a quiet Finder-adjacent folio; document windows are disciplined desks with native chrome and uninterrupted canvas. System typography, semantic colors/materials, native spacing, and one accent; no browser navbar or website dashboard styling.

## Concurrency
AppKit/WebKit/SwiftUI document and bridge coordinators are `@MainActor`. File hashing and PDF rendering use bounded work with Sendable values. Non-Sendable framework objects never cross actors.

## Risks
- Stable npm 0.18.1 differs from current master documentation; installed declarations are authoritative.
- Official serialization normalizes data; unknown compatible top-level fields require an explicit merge contract and fixtures.
- Automation cannot prove physical mouse feel or full canvas accessibility.
- Ad-hoc signing proves local package integrity, not notarized distribution.
