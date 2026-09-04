# ADR 0004: Import and export semantics

**Status:** Accepted — 2026-09-02

Editable `.excalidraw` and scene-embedded PNG/SVG remain structurally editable. Ordinary raster images and SVG import as image elements. PDFKit presents thumbnails/page selection and renders chosen pages as bounded image elements; no OCR or vector-edit claim. Export supports editable/plain scene formats and PDF, with a vector-preferred path and documented raster fallback. Native panels and safe replacement own destinations.
