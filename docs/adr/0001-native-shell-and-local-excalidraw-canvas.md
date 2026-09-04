# ADR 0001: Native shell and local Excalidraw canvas

**Status:** Accepted — 2026-09-02

A website wrapper would fail the required macOS document lifecycle, Finder integration, organizer/history, native commands, accessibility, and security ownership. Rewriting Excalidraw rendering and element behavior in Swift now would forfeit file compatibility and mature drawing interaction.

Build the shell in AppKit/SwiftUI and embed pinned official Excalidraw locally in one isolated WKWebView per document. Native owns lifecycle, windows, menus, files, organizer, history, import/export, Settings, security, errors, and packaging. WebKit owns only drawing tools, rendering, element semantics, canvas interaction/history, official restore/serialization, and official embedded-export helpers.

No live website, browser navbar, remote asset, web file dialog, collaboration/share shell, or canonical localStorage is permitted. A typed versioned bridge is the sole seam.

A future zero-WebKit renderer would implement the same semantic CanvasSession contract: load a compatible scene, edit, emit dirty/metadata, snapshot, import binary, and export. Native document/catalog/history code remains; replacement requires fixture and interaction parity first.
