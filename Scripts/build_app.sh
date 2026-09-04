#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA="$ROOT/build/DerivedData"

"$ROOT/Scripts/build_canvas.sh"
xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT"
xcodebuild \
  -project "$ROOT/Excalidays.xcodeproj" \
  -scheme Excalidays \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA" \
  build

echo "$DERIVED_DATA/Build/Products/$CONFIGURATION/Excalidays.app"
