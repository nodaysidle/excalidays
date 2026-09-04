#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/build/DerivedData/Build/Products/Release/Excalidays.app"
DESTINATION="$ROOT/Artifacts/Excalidays.app"

"$ROOT/Scripts/build_app.sh" Release
rm -rf "$DESTINATION"
mkdir -p "$ROOT/Artifacts"
ditto "$SOURCE" "$DESTINATION"
echo "$DESTINATION"
