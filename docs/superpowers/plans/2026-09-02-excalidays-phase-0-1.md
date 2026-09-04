# Excalidays Phase 0–1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use test-driven-development and verification-before-completion. Steps use checkbox syntax.

**Goal:** Build a packaged native NSDocument macOS shell with a pinned local Excalidraw runtime and tested `.excalidraw` save/reopen vertical slice.

**Architecture:** AppKit owns documents/windows/files and SwiftUI hosts native Library/document surfaces. One local secure WKWebView per document runs a typed TypeScript adapter around official Excalidraw 0.18.1; full scene data crosses only for explicit snapshots.

**Tech Stack:** Swift 6, AppKit, SwiftUI, WebKit, UniformTypeIdentifiers, XCTest/XCUITest, TypeScript, React, Vite, Vitest, Excalidraw 0.18.1.

## Constraints
- Work only under the project root.
- macOS 14, Swift 6 complete strict concurrency.
- No commit/push/remote/install/Developer ID/notarization.
- No remote runtime assets or network entitlement.

### Task 1: Bridge contract
- [ ] Write TypeScript and Swift tests for valid request, mismatch, unknown operation, and reply ID; observe red.
- [ ] Implement discriminated union/Codable validation; run green.

### Task 2: Runtime snapshot adapter
- [ ] Test dirty coalescing, explicit snapshots, attachments, unknown top-level fields, destroyed guard; observe red.
- [ ] Implement official load/serialize/files adapter and restrictive CSP; run tests/build and inspect dist.

### Task 3: Native documents and windows
- [ ] Test document envelope/UTI/network policy; observe red.
- [ ] Implement bounded model, NSDocument, controllers, native Library, and secure web host.
- [ ] Generate Xcode project/shared scheme and run tests.

### Task 4: Save/reopen vertical slice
- [ ] Test compatible-field and attachment round-trip plus dirty/command routing; observe red.
- [ ] Implement staged snapshots, native edited state, save orchestration, undo/redo forwarding.
- [ ] Exercise a fixture save/reopen flow.

### Task 5: Package evidence
- [ ] Implement six canonical scripts.
- [ ] Build Release, package and ad-hoc sign without `/Applications`.
- [ ] Verify metadata/resources/no remote refs/signature/launch.
- [ ] Capture screenshot and update TASKS/evidence truthfully.
