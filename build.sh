#!/bin/bash
set -e

VERSION="1.0.0"
APP_NAME="ez-paste"
BINARY_NAME="EzPaste"
BUNDLE_ID="com.ben.ez-paste"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Signing identity — pass via env or argument, e.g.:
#   SIGNING_IDENTITY="Developer ID Application: Ben (...)" ./build.sh
SIGNING_IDENTITY="${SIGNING_IDENTITY:-${1:-}}"

echo "Building $APP_NAME v$VERSION..."
cd "$PROJECT_DIR"
swift build -c release

BINARY_PATH="$PROJECT_DIR/.build/release/$BINARY_NAME"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

# Clean up previous build
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

# Copy binary
cp "$BINARY_PATH" "$MACOS/$APP_NAME"

# Build .icns app icon
ICONSET="$PROJECT_DIR/AppIcon.iconset"
ICON_SRC="/Users/ben/Downloads/AppIconAssets_iOS_macOS_v4/icons"
mkdir -p "$ICONSET"
cp "$ICON_SRC/icon_16x16.png"     "$ICONSET/icon_16x16.png"
cp "$ICON_SRC/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
cp "$ICON_SRC/icon_32x32.png"     "$ICONSET/icon_32x32.png"
cp "$ICON_SRC/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
cp "$ICON_SRC/icon_128x128.png"   "$ICONSET/icon_128x128.png"
cp "$ICON_SRC/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
cp "$ICON_SRC/icon_256x256.png"   "$ICONSET/icon_256x256.png"
cp "$ICON_SRC/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
cp "$ICON_SRC/icon_512x512.png"   "$ICONSET/icon_512x512.png"
cp "$ICON_SRC/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

# Copy resources
mkdir -p "$CONTENTS/Resources"
cp "$PROJECT_DIR/Resources/"* "$CONTENTS/Resources/"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>EZ Paste</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Code sign, notarize, and staple
if [ -n "$SIGNING_IDENTITY" ]; then
    echo ""
    echo "Signing with: $SIGNING_IDENTITY"
    codesign --force --options runtime \
        --entitlements "$PROJECT_DIR/entitlements.plist" \
        --sign "$SIGNING_IDENTITY" \
        "$APP_BUNDLE"
    echo "Signed."

    # Create zip for notarization
    rm -f "$PROJECT_DIR/ez-paste.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$PROJECT_DIR/ez-paste.zip"

    echo ""
    echo "Submitting for notarization..."
    xcrun notarytool submit "$PROJECT_DIR/ez-paste.zip" \
        --keychain-profile "ez-paste-notary" \
        --wait

    echo ""
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"

    echo ""
    echo "Notarized and stapled."
else
    echo ""
    echo "WARNING: No signing identity provided. Skipping code signing and notarization."
    echo "  Set SIGNING_IDENTITY env var or pass as first argument to enable signing."
    echo "  Example: SIGNING_IDENTITY=\"Developer ID Application: Name (TEAMID)\" ./build.sh"
    echo ""
fi

# Create DMG with drag-to-Applications layout
DMG_NAME="$APP_NAME-$VERSION"
DMG_TEMP="$PROJECT_DIR/${DMG_NAME}-temp.dmg"
DMG_FINAL="$PROJECT_DIR/${APP_NAME}.dmg"
DMG_STAGING="$PROJECT_DIR/.dmg-staging"
VOLUME_NAME="$APP_NAME $VERSION"

echo "Creating DMG..."

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Create a temporary read-write DMG
rm -f "$DMG_TEMP"
hdiutil create -srcfolder "$DMG_STAGING" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size 200m \
    "$DMG_TEMP"

# Mount the DMG and configure Finder window layout
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 640, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "$APP_NAME.app" of container window to {140, 150}
        set position of item "Applications" of container window to {400, 150}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Set the DMG volume icon to the app icon
cp "$CONTENTS/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR"

sync
hdiutil detach "$MOUNT_DIR"

# Convert to compressed read-only DMG
rm -f "$DMG_FINAL"
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_TEMP"
rm -rf "$DMG_STAGING"

# Also notarize the DMG if we have a signing identity
if [ -n "$SIGNING_IDENTITY" ]; then
    echo ""
    echo "Notarizing DMG..."
    xcrun notarytool submit "$DMG_FINAL" \
        --keychain-profile "ez-paste-notary" \
        --wait
    xcrun stapler staple "$DMG_FINAL"
    echo "DMG notarized and stapled."
fi

echo ""
echo "Built: $APP_BUNDLE (v$VERSION)"
echo "DMG:   $DMG_FINAL"
