#!/usr/bin/env bash
# Attach a locally built DMG/APK/zip to an existing GitHub Release for this tag.
# Usage: Scripts/attach-release-asset.sh v0.2.0 ./path/to/Excalidays-0.2.0.dmg
set -euo pipefail

TAG="${1:-}"
ASSET="${2:-}"
REPO="${REPO:-nodaysidle/excalidays}"

if [[ -z "$TAG" || -z "$ASSET" ]]; then
  echo "Usage: $0 <tag> <asset-path>" >&2
  exit 1
fi
if [[ ! -f "$ASSET" ]]; then
  echo "Asset not found: $ASSET" >&2
  exit 1
fi

if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Release $TAG not found on $REPO. Push the tag first so CI can create the release, or:" >&2
  echo "  gh release create \"$TAG\" --repo \"$REPO\" --generate-notes --title \"Excalidays $TAG\"" >&2
  exit 1
fi

gh release upload "$TAG" "$ASSET" --repo "$REPO" --clobber
echo "Attached $(basename "$ASSET") → $TAG on $REPO"
