# ADR 0002: NSDocument and file-format strategy

**Status:** Accepted — 2026-09-02

Use a real NSDocument subclass and AppKit safe-save behavior. Keep scene JSON opaque in Swift except for bounded envelope checks. Official runtime APIs restore and serialize known scene data; compatible unknown top-level fields are retained/merged and verified by fixtures. Declare `com.excalidraw.excalidraw` as an imported UTI because no canonical official UTI was found and Excalidays does not own the format. Finder maps `.excalidraw` to the document class.
