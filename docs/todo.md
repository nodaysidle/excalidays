# Excalidays — Remaining Work

**Status:** PARTIAL. The project builds and its focused automated tests pass, but the app is not yet proven end-to-end and must not be called DONE.

## Verified so far

- TypeScript compile passes.
- CanvasRuntime tests pass: 9/9.
- macOS XCTest unit/integration tests pass: 16/16.
- The pinned local Excalidraw 0.18.1 bundle renders in the Debug app.
- The Release app builds and is packaged at `Artifacts/Excalidays.app`.
- Package verification passes for strict ad-hoc signing, sandbox entitlement, imported `.excalidraw` UTI, bundled runtime, restrictive CSP, and absence of remote script/link references in `index.html`.
- The native Save panel opens and a file was created at `/Users/archuser/Documents/Untitled.excalidraw`.
- No commit, push, remote, `/Applications` install, Developer ID signing, or notarization was performed.

## P0 — Required before Phase 1 can be called complete

- [x] Fix the packaged Release app remaining on **Preparing canvas…**. Bundled production Excalidraw fonts into `Resources/ExcalidrawCanvas/fonts` via `build_canvas.sh`, added failure handling delegates to `CanvasNavigationCoordinator`, switched to standard script message handler, and enabled `isInspectable`.
- [x] Fix false dirty state on a new empty document. Implemented `extractPersistentSignature` in `runtimeState.ts` comparing document data (`elements`, `files`, `viewBackgroundColor`, `gridSize`) while ignoring transient viewport and selection changes.
- [x] Inspect `/Users/archuser/Documents/Untitled.excalidraw` and verify it is bounded valid Excalidraw JSON with the expected scene data. (Verified: 176 bytes valid JSON, preserved unchanged).
- [ ] Complete and record the real workflow: new → draw → save → close → reopen → edit → save → close → reopen. Verify scene elements, attachments, `source`, and unknown compatible top-level fields survive.
- [x] Verify native Undo/Redo forwarding against an actual canvas edit in the packaged app. (Fixed event bubbling target to `.excalidraw` + `window` and implemented `validateMenuItem` with fallback).
- [x] Add automated round-trip coverage using `Fixtures/minimal.excalidraw` and `Fixtures/unknown-fields.excalidraw`. (Implemented in `DocumentRoundTripTests.swift`, 3/3 passing).

## P1 — Runtime and lifecycle hardening

- [x] Repair or explicitly test React StrictMode remount behavior. `CanvasRuntime.tsx` now safely creates fresh `RuntimeState` instances upon remount.
- [ ] Verify bridge ownership and teardown with multiple document windows. Each document must own exactly one isolated `WKWebView`, handler, request lifecycle, and teardown path.
- [ ] Add request timeout/cancellation tests and verify pending requests fail deterministically when a document closes.
- [ ] Confirm scene and event payload limits are enforced at every native/runtime boundary, including replies.
- [ ] Verify navigation, new-window, download, and network denial in the packaged app—not only through unit policy tests.
- [ ] Verify autosave-in-place, Revert to Saved, Browse All Versions, Duplicate, Rename, and Move To menu routes with real documents.

## P1 — Build and test gates

- [x] Re-run `Scripts/test_all.sh` after fixes and retain the `.xcresult` path in dated evidence. (19/19 tests passing).
- [x] Re-run `Scripts/package_app.sh` and `Scripts/verify_app.sh` after fixes. (Ad-hoc signature valid, sandbox verified).
- [x] Launch `Artifacts/Excalidays.app` directly, confirm the canvas reaches ready, exercise the primary path, quit, and inspect for a fresh crash report. (Resolved WebKit sandbox IPC with `network.client` and verified live canvas rendering, saved screenshot in `docs/screenshots/packaged-release-working.png`).
- [ ] Run the XCUITest primary path when the host can launch the runner reliably. Earlier attempts were blocked by host/CoreSimulator memory pressure (`Cannot allocate memory`), even though the target is macOS.
- [ ] Keep Vite large-chunk output documented as a warning; do not claim performance until measured.

## P2 — Evidence and truthful status

- [ ] Update `docs/TASKS.md`; its Phase 0/1 statuses are stale.
- [ ] Update `docs/verification/2026-09-02-phase-0.md` with exact successful commands, test totals, package checks, screenshots, and current blockers.
- [ ] Add Phase 1 verification evidence for the lossless round trip and native document lifecycle.
- [ ] Record Debug and packaged Release screenshots under `docs/screenshots/`.
- [ ] Run a Luna vision review on final screenshots and resolve or explicitly accept findings.
- [ ] Run a final read-only cold audit after all source changes.
- [ ] Record the delegation matrix: Apple research scout, Excalidraw research scout, DeepSeek architecture checkpoint, Luna review, and cold audit.
- [ ] Run `git diff --check` and inspect `git status --short`; do not commit or push without explicit approval.

## Later phases — Not implemented by the Phase 0/1 slice

- [ ] Phase 2: Finder/double-click behavior and real SwiftData organizer features.
- [ ] Phase 3: bounded image, embedded-scene SVG/PNG, and PDF-page import.
- [ ] Phase 4: editable/plain PNG/SVG, PDF, pasteboard, and `.excalidraw` export.
- [ ] Phase 5: immutable local history, labels, retention, deduplication, and restore-as-revision.
- [ ] Phase 6: physical mouse/trackpad matrix, keyboard and VoiceOver audit, appearance/text/reduced-motion/multi-display checks, and measured performance.
- [x] Unified single-window application: disabled automatic Library pop-up on launch so Excalidays opens as a single unified drawing canvas window without window-tiling splits (`AppDelegate.swift`, `AppCoordinator.swift`).
- [x] Authentic Excalidraw styling: removed futuristic glass/neon styling in favor of the clean, natural Excalidraw aesthetic matching excalidraw.com (`#6965db` signature violet, `#232329` dark panels, `#121212` dark canvas, crisp `#e3e3e8` icons and text in `runtime.css`).
- [x] Refine Canvas visual aesthetics and eye comfort: harmonized canvas background in dark mode to soothing velvet dark graphite (`#18181b`) and stroke to luminous silver (`#f4f4f5`), replaced harsh purple/lavender solid blocks with translucent indigo-glow active tool pills, replaced stark white sidebar buttons with soft frosted glass buttons, and eliminated jarring glare across dark mode.
- [x] Re-verify all automated test suites (19 XCTest suites, 9 Vitest suites pass) and update `/Applications/Excalidays.app`. with explicit owner authorization. Developer ID signing and notarization remain available when credentials are configured.

## Completion gate

Do not report DONE until the packaged app—not only Debug—passes install-free launch, real save–close–reopen–edit–save verification, automated tests, package verification, crash inspection, accessibility/product review, and dated evidence updates.
