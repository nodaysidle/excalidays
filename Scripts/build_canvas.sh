#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/CanvasRuntime"
DESTINATION="$ROOT/Excalidays/Resources/ExcalidrawCanvas"

npm run build --prefix "$RUNTIME"
mkdir -p "$DESTINATION"
rsync -a --delete --exclude='.keep' "$RUNTIME/dist/" "$DESTINATION/"

# Copy Excalidraw production fonts so local offline font loading works
mkdir -p "$DESTINATION/fonts"
rsync -a "$RUNTIME/node_modules/@excalidraw/excalidraw/dist/prod/fonts/" "$DESTINATION/fonts/"

test -f "$DESTINATION/index.html"
echo "Canvas runtime copied to $DESTINATION"
