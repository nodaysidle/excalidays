# Excalidays Agent Contract

**Authority:** 5 of 5. Every implementation agent MUST read, in order, `PRD.md`, `ARD.md`, `TRD.md`, `TASKS.md`, and this file before editing.

## Scope
Work only inside `/Volumes/omarchyuser/projekti/excalidays`. Preserve user files. No commit, push, remote, `/Applications` install, sudo, Homebrew mutation, Developer ID signing, notarization, credential search, or secret inspection without explicit owner authorization.

## Execution
1. Re-read the authority cascade before each phase.
2. Keep TASKS.md truthful with DONE/PARTIAL/BLOCKED/NOT STARTED and evidence.
3. Use TDD: write focused failing test, run and observe expected failure, implement minimally, rerun focused and broad tests.
4. On failure, reproduce and identify root cause before patching.
5. Use official current Apple and Excalidraw sources; installed package declarations override stale examples.
6. Do not claim placeholder UI as behavior.
7. Captain personally verifies delegated results in the parent workspace.

## Architecture guardrails
- Native Swift/AppKit/SwiftUI shell; one isolated local Excalidraw WKWebView per document.
- Real NSDocument/NSDocumentController/NSWindowController lifecycle.
- Runtime has no remote assets, navigation, arbitrary dispatch, filesystem paths, or canonical localStorage.
- Never serialize full scene on pointer movement; use dirty events and explicit snapshots.
- Swift retains opaque scene data and must not drop compatible unknown fields.
- Ordinary images/PDF pages are image elements, not shape-editable.
- No cloud/account/collaboration/analytics/speculative framework.

## Quality
Swift 6, complete strict concurrency, macOS 14 floor. Keep AppKit/WebKit objects on MainActor. Keep views small, semantic, keyboard accessible, and system-styled. Remove message handlers and release web views on close. Bound all untrusted input and avoid document-content/path logging.

## Verification
Use the six Scripts as canonical interface. Before completion claims run focused tests, full tests, Release build, package verification, launch smoke, Git diff/status, and update dated evidence. Physical mouse and full canvas accessibility remain PARTIAL unless actually tested.
