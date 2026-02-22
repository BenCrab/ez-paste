#!/bin/bash
set -e

APP_NAME="ez-paste"
BINARY_NAME="EzPaste"
BUNDLE_ID="com.ben.ez-paste"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building $APP_NAME..."
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
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
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


# Create distributable zip
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$PROJECT_DIR/ez-paste.zip"

echo ""
echo "Built: $APP_BUNDLE"
echo "Zip:   $PROJECT_DIR/ez-paste.zip"
echo ""
echo "To install, run:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "Then add ez-paste to Login Items:"
echo "  System Settings → General → Login Items & Extensions → + → select ez-paste"
echo ""
echo "First launch: right-click the .app → Open (to bypass Gatekeeper)"
