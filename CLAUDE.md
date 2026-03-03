# EZ Paste

A Mac menu bar app for pasting partial screenshots into Claude Code.

## Build

```bash
# Unsigned (development)
./build.sh

# Signed + notarized (release)
SIGNING_IDENTITY="Developer ID Application: ..." ./build.sh
```

Signing requires the `ez-paste-notary` keychain profile (see build.sh comments).

## Release Workflow

1. Bump `VERSION` in `build.sh`
2. Run `SIGNING_IDENTITY="Developer ID Application: ..." ./build.sh` to build, sign, notarize, and create DMG
3. Create a GitHub release with the new version tag and upload `ez-paste.dmg`:
   ```bash
   gh release create vX.Y.Z ez-paste.dmg --title "vX.Y.Z" --notes "Release notes here"
   ```
