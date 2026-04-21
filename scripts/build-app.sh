#!/bin/bash
# Build SwiftGrabApp and wrap it in a minimal .app bundle so macOS
# treats it as a real application (menu bar items, permissions, etc.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="SwiftGrab"
APP_BUNDLE="$PROJECT_DIR/.build/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"

cd "$PROJECT_DIR"

echo "Building SwiftGrabApp..."
swift build -c debug 2>&1

echo "Updating app bundle in place..."
mkdir -p "$MACOS_DIR"

# Overwrite the binary only — keep the bundle directory (and its inode/xattrs)
# stable so TCC keeps recognizing the app across rebuilds.
cp .build/debug/SwiftGrabApp "$MACOS_DIR/$APP_NAME"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SwiftGrab</string>
    <key>CFBundleDisplayName</key>
    <string>SwiftGrab</string>
    <key>CFBundleIdentifier</key>
    <string>com.swiftgrab.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>SwiftGrab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Prefer an Apple Development identity — stable across rebuilds so TCC keeps
# the Accessibility grant. Fall back to ad-hoc (`-`) if none is installed.
SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development:/ {print $2; exit}')"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
fi
echo "Code signing ($SIGN_IDENTITY)..."
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
echo ""
echo "Run with:  open $APP_BUNDLE"
echo "Or:        $MACOS_DIR/$APP_NAME"
