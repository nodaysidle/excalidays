# Hybrid release flow

Local Mac builds the DMG; CI only creates the GitHub Release with generated notes when a version tag is pushed.

1. **Build the DMG locally** on the Mac (existing packaging scripts).
2. **Tag and push** a version tag (`v*`), e.g. `git tag v0.2.0 && git push origin v0.2.0`.
3. **CI creates the release** (`.github/workflows/release-on-tag.yml`) with generated notes — no binaries.
4. **Attach the DMG** with `Scripts/attach-release-asset.sh`:

   ```bash
   Scripts/attach-release-asset.sh v0.2.0 ./path/to/Excalidays-0.2.0.dmg
   ```
