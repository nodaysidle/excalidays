# Security and Privacy

Excalidays operates locally by default. It has no account, analytics, telemetry, collaboration, automatic upload, remote UI assets, or network fallback.

Report security issues privately to the repository owner. Do not include private drawings, full paths, credentials, or personal data.

The canvas is bundled local code in a restricted WKWebView. Inputs are content-sniffed and bounded; external navigation/resources are denied; document writes use native safe-save semantics. See ADR 0005.
