# Excalidays Tasks and Evidence

**Authority:** 4 of 5. docs/specs/PRD.md, docs/specs/ARD.md, and docs/specs/TRD.md override this file. Status values: DONE, PARTIAL, BLOCKED, NOT STARTED.

## Phase 0 — Research, contracts, native shell
- DONE — Environment inspection and local Git initialization recorded in `docs/verification/2026-09-02-phase-0.md`.
- DONE — Official Apple/Excalidraw research completed with two read-only delegate receipts and recorded in `docs/research/2026-09-02-apple-excalidraw-research.md`.
- DONE — Authority cascade and five required ADRs authored.
- DONE — Xcode project/shared scheme and test targets via `project.yml` and `xcodegen`.
- DONE — Native document window and real `NSDocument` (`ExcalidaysDocument`) type.
- DONE — Pinned CanvasRuntime, local fonts/assets, CSP, and runtime tests (9/9 pass).
- DONE — Debug tests, Release build, ad-hoc package, launch smoke verified.

## Phase 1 — Editable `.excalidraw` vertical slice
- DONE — Test-first bridge envelope and operation allowlist (`CanvasBridgeMessageTests`, `CanvasSessionTests`).
- DONE — Runtime load, lightweight dirty event, explicit snapshot (`runtimeState.ts`, `CanvasRuntime.tsx`).
- DONE — Compatible scene/files/unknown-field round trip (`DocumentRoundTripTests`, fixtures verified).
- DONE — Native dirty indicator and save orchestration (`ExcalidaysDocument.swift`, `DocumentContentView.swift`).
- DONE — Native undo/redo forwarding (`DocumentRoundTripTests.testUndoRedoMenuItemValidation`).
- DONE — Unified single-window application and authentic Excalidraw design system (`AppDelegate.swift`, `runtime.css`).

## Phase 2 — Finder and organizer
- NOT STARTED — Finder association/double-click and drag/drop.
- NOT STARTED — SwiftData catalog, recents, favorites, tags, thumbnails, workspaces, missing files.
- NOT STARTED — Complete native menus and toolbar.

## Phase 3 — Import
- NOT STARTED — Embedded-scene PNG/SVG detection.
- NOT STARTED — Ordinary image/SVG image-element import.
- NOT STARTED — PDFKit chooser and bounded page-image import.

## Phase 4 — Export
- NOT STARTED — Editable/plain PNG/SVG and `.excalidraw`.
- NOT STARTED — PDF frame/full-drawing export and pasteboard.

## Phase 5 — History
- NOT STARTED — Immutable checkpoints, manual labels, restore-as-revision.
- NOT STARTED — Deduplication, retention, browser, native Revert integration.

## Phase 6 — Interaction, accessibility, performance
- NOT STARTED — Mouse/trackpad manual matrix.
- NOT STARTED — Keyboard/native-shell VoiceOver audit.
- NOT STARTED — Appearance/text/reduced-motion/multi-display/performance evidence.

## Phase 7 — Release readiness
- NOT STARTED — Icons/notices/release package/strict ad-hoc verification.
- BLOCKED — Developer ID signing and notarization require owner authorization and configured credentials.
- BLOCKED — `/Applications` installation requires owner authorization.

## Completion rule
Never mark work DONE without exact commands/workflows and dated evidence under `docs/verification/`.
