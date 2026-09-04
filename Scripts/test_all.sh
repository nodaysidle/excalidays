#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT/build/DerivedData"

cd "$ROOT/CanvasRuntime"
./node_modules/.bin/tsc -p tsconfig.json
./node_modules/.bin/vitest run

"$ROOT/Scripts/build_canvas.sh"
xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"
xcodebuild \
  -project "$ROOT/Excalidays.xcodeproj" \
  -scheme Excalidays \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  -only-testing:ExcalidaysTests \
  test CODE_SIGNING_ALLOWED=NO
