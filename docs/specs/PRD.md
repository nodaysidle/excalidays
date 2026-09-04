# Excalidays Product Requirements Document

**Authority:** 1 of 5. This file overrides docs/specs/ARD.md, docs/specs/TRD.md, docs/TASKS.md, and docs/AGENTS.md.

## Product promise
Excalidays is a local-first native macOS document application for creating, opening, editing, organizing, importing, versioning, and exporting Excalidraw drawings. The application behaves like an Apple document app; the official Excalidraw package is an isolated local canvas engine, not the application shell.

## Core jobs
- Create and edit familiar Excalidraw drawings in ordinary user-owned files.
- Open `.excalidraw` files from Finder while preserving compatible data and attachments.
- Organize recents, favorites, tags, and user-approved workspace folders.
- Import ordinary images as image elements and selected PDF pages as bounded image elements.
- Export editable and presentation formats through native macOS workflows.
- Recover earlier work through native autosave/revert and immutable in-app history.

## Experience principles
1. Native first: windows, menus, toolbars, sheets, alerts, file panels, focus, keyboard navigation, accessibility, and multiwindow behavior are AppKit/SwiftUI.
2. Canvas familiar: drawing tools and element interaction remain Excalidraw behavior.
3. Honest semantics: editable embedded scenes are distinct from plain images; ordinary image pixels, SVG paths, and PDF pages are not claimed as shape-editable.
4. Local and private: no account, telemetry, collaboration, cloud requirement, remote UI asset, CDN fallback, or automatic upload.
5. Files remain files: canonical drawing contents live at user-selected URLs; catalog metadata is not a replacement document store.
6. Failure is recoverable: atomic writes, bounded imports, explicit errors, and restorable history.

## Native surfaces
- Library/Welcome window when no document is open.
- One document window and isolated `WKWebView` per open document.
- Standard File/Edit/View/Window/Help menus and document toolbar.
- Native Settings, import/export sheets, History browser, alerts, and file panels.

## Format semantics
### Editable
- `.excalidraw`: official runtime restoration/serialization; preserve elements, app state, files, attachments, and compatible unknown top-level data.
- Scene-embedded PNG/SVG: detect with official helpers and open as editable when valid; export with embedded scene when supported.
### Image-element imports
- PNG, JPEG, WebP, GIF, HEIC, and ordinary SVG become image elements. They can be transformed and annotated, but their pixels/paths do not become native Excalidraw shapes.
- PDF pages are selected in a PDFKit sheet and rendered as bounded image elements. No OCR or arbitrary vector conversion in MVP.

## Delivery phases
- Phase 0: research, contracts, native shell, real document type, local canvas bundle, tests, ad-hoc package and launch.
- Phase 1: real new/draw/save/close/reopen/edit/save `.excalidraw` vertical slice with typed bridge and dirty state.
- Phase 2: Finder declarations, organizer metadata, workspaces, thumbnails, menus, toolbar.
- Phase 3: embedded-scene detection plus ordinary image/SVG/PDF imports.
- Phase 4: editable/plain PNG/SVG, `.excalidraw`, PDF, and pasteboard exports.
- Phase 5: immutable history, restore-as-new-revision, retention, attachment deduplication.
- Phase 6: mouse, trackpad, keyboard, accessibility, appearance, multi-display, performance evidence.
- Phase 7: release build, icons, notices, ad-hoc ZIP/DMG; Developer ID and notarization require owner authorization.

## Non-goals
Accounts, cloud sync, collaboration, shared links, analytics, AI drawing, mobile apps, browser extensions, plugins, OCR, editable PDF-vector conversion, SVG-to-shape conversion, custom renderer, and remote templates.

## Accessibility promise
Native shell controls provide labels, focus, keyboard access, semantic colors, reduced-motion behavior, and light/dark appearance. Canvas accessibility is reported separately and is never inferred from native-shell compliance.

## Success criteria
A phase is complete only when its focused tests pass, the app builds, its workflow is personally exercised, and docs/TASKS.md links dated evidence. Placeholder UI is not completion.

## Licensing
The Excalidays application license is owner-controlled and intentionally undecided. This does not block local development. Excalidraw and bundled third-party notices must be preserved.
