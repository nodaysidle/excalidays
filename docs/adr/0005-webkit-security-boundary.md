# ADR 0005: WebKit security boundary

**Status:** Accepted — 2026-09-02

Load only bundle-local runtime files with the smallest read-access root. Apply restrictive CSP, nonpersistent data store, navigation/response denial, no new windows/downloads, no HTTP(S)/WebSocket, and no network entitlement. Use an operation allowlist, protocol/version validation, payload bounds, request IDs, timeouts, content worlds, and handler teardown. Never expose credentials or filesystem paths. Treat the runtime as untrusted at the bridge boundary even though its code is bundled.
