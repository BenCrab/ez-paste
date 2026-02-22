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

# Copy resources
mkdir -p "$CONTENTS/Resources"
cp "$PROJECT_DIR/Resources/"* "$CONTENTS/Resources/"

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
</dict>
</plist>
EOF


echo ""
echo "Built: $APP_BUNDLE"
echo ""
echo "To install, run:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "Then add ez-paste to Login Items:"
echo "  System Settings → General → Login Items & Extensions → + → select ez-paste"
echo ""
echo "First launch: right-click the .app → Open (to bypass Gatekeeper)"
