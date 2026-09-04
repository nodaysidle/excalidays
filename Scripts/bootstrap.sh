#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for tool in node npm xcodegen xcodebuild; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

npm ci --include=dev --prefix "$ROOT/CanvasRuntime"
xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"
echo "Bootstrap complete."
