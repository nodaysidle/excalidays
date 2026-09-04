#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/Artifacts/Excalidays.app}"
PLIST="$APP/Contents/Info.plist"
CANVAS="$APP/Contents/Resources/ExcalidrawCanvas"

[ -d "$APP" ] || { echo "Missing app: $APP" >&2; exit 1; }
[ -f "$CANVAS/index.html" ] || { echo "Missing bundled canvas index" >&2; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" | grep -Fx 'com.nodaysidle.excalidays' >/dev/null
/usr/libexec/PlistBuddy -c 'Print :UTImportedTypeDeclarations:0:UTTypeIdentifier' "$PLIST" | grep -Fx 'com.excalidraw.excalidraw' >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundleDocumentTypes:0:CFBundleTypeRole' "$PLIST" | grep -Fx 'Editor' >/dev/null
if grep -E "<(script|link)[^>]+(src|href)=['\"]https?://" "$CANVAS/index.html"; then
  echo "Remote runtime reference found in index.html" >&2
  exit 1
fi
grep -F "connect-src 'none'" "$CANVAS/index.html" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APP" 2>&1 | grep -F 'com.apple.security.app-sandbox' >/dev/null
echo "Verified $APP"
