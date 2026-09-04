# ADR 0003: Version history storage

**Status:** Accepted — 2026-09-02

Use native autosave/revert plus independent immutable history under Application Support. Index metadata lives in SwiftData; scene objects and attachments use content-addressed storage and atomic manifests. Explicit saves, debounced active checkpoints, manual versions, and pre-destructive operations create snapshots. Restore creates a new current revision and never erases later history. Pinned/manual records bypass automatic retention.
