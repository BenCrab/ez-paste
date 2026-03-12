#!/bin/bash
set -e

VERSION="1.0.0"
APP_NAME="ez-paste"
BINARY_NAME="EzPaste"
BUNDLE_ID="com.ben.ez-paste"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTARY_MODE="${NOTARY_MODE:-wait}" # wait|notify
NOTARY_PROFILE="${NOTARY_PROFILE:-ez-paste-notary}"
NOTARY_NOTIFY_SCRIPT="$PROJECT_DIR/scripts/notary-submit-and-notify.sh"

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
    if [ "$NOTARY_MODE" = "notify" ]; then
        "$NOTARY_NOTIFY_SCRIPT" "$PROJECT_DIR/ez-paste.zip" "$NOTARY_PROFILE" "ez-paste app notarization" "$APP_BUNDLE"
    else
        xcrun notarytool submit "$PROJECT_DIR/ez-paste.zip" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait

        echo ""
        echo "Stapling notarization ticket..."
        xcrun stapler staple "$APP_BUNDLE"

        echo ""
        echo "Notarized and stapled."
    fi
else
    echo ""
    echo "WARNING: No signing identity provided. Skipping code signing and notarization."
    echo "  Set SIGNING_IDENTITY env var or pass as first argument to enable signing."
    echo "  Example: SIGNING_IDENTITY=\"Developer ID Application: Name (TEAMID)\" ./build.sh"
    echo ""
fi

# Create DMG with drag-to-Applications layout
DMG_FINAL="$PROJECT_DIR/${APP_NAME}.dmg"
DMG_STAGING="$PROJECT_DIR/.dmg-staging"
VOLUME_NAME="$APP_NAME $VERSION"

echo "Creating DMG..."

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Copy volume icon into staging
cp "$CONTENTS/Resources/AppIcon.icns" "$DMG_STAGING/.VolumeIcon.icns"
SetFile -c icnC "$DMG_STAGING/.VolumeIcon.icns"
SetFile -a C "$DMG_STAGING"

# Create compressed DMG directly
rm -f "$DMG_FINAL"
hdiutil create -srcfolder "$DMG_STAGING" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_FINAL"
rm -rf "$DMG_STAGING"

# Sign and notarize the DMG if we have a signing identity
if [ -n "$SIGNING_IDENTITY" ]; then
    echo ""
    echo "Signing DMG..."
    codesign --force --sign "$SIGNING_IDENTITY" "$DMG_FINAL"

    echo "Notarizing DMG..."
    if [ "$NOTARY_MODE" = "notify" ]; then
        "$NOTARY_NOTIFY_SCRIPT" "$DMG_FINAL" "$NOTARY_PROFILE" "ez-paste dmg notarization" "$DMG_FINAL"
    else
        xcrun notarytool submit "$DMG_FINAL" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait
        xcrun stapler staple "$DMG_FINAL"
        echo "DMG notarized and stapled."
    fi
fi

echo ""
echo "Built: $APP_BUNDLE (v$VERSION)"
echo "DMG:   $DMG_FINAL"
if [ "$NOTARY_MODE" = "notify" ]; then
    echo "Notary: submitted in background (notifications enabled)."
fi
