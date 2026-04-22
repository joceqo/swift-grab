#!/bin/bash
# Build SwiftGrabApp and wrap it in a minimal .app bundle so macOS
# treats it as a real application (menu bar items, permissions, etc.)
#
# Environment overrides:
#   CONFIGURATION   debug (default) | release
#   SIGN_IDENTITY   codesign identity; auto-picks best available if unset
#                   (prefers "Developer ID Application" for release, then
#                   "Apple Development" for debug, falls back to ad-hoc "-")
#   HARDENED        0 (default) | 1 — enable hardened runtime (required for
#                   notarization). Auto-on when SIGN_IDENTITY starts with
#                   "Developer ID Application".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="SwiftGrab"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_BUNDLE="$PROJECT_DIR/.build/${APP_NAME}.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ENTITLEMENTS="$PROJECT_DIR/Sources/SwiftGrabApp/SwiftGrabApp.entitlements"
ICONSET_SRC="$PROJECT_DIR/Sources/SwiftGrabApp/Assets.xcassets/AppIcon.appiconset"

cd "$PROJECT_DIR"

echo "Building SwiftGrabApp ($CONFIGURATION)..."
swift build -c "$CONFIGURATION" 2>&1

echo "Updating app bundle in place..."
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Build .icns from iconset PNGs
if [ -d "$ICONSET_SRC" ]; then
    ICONSET_TMP="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET_TMP"
    cp "$ICONSET_SRC"/icon_16x16.png       "$ICONSET_TMP/icon_16x16.png"
    cp "$ICONSET_SRC"/icon_16x16@2x.png    "$ICONSET_TMP/icon_16x16@2x.png"
    cp "$ICONSET_SRC"/icon_32x32.png       "$ICONSET_TMP/icon_32x32.png"
    cp "$ICONSET_SRC"/icon_32x32@2x.png    "$ICONSET_TMP/icon_32x32@2x.png"
    cp "$ICONSET_SRC"/icon_128x128.png     "$ICONSET_TMP/icon_128x128.png"
    cp "$ICONSET_SRC"/icon_128x128@2x.png  "$ICONSET_TMP/icon_128x128@2x.png"
    cp "$ICONSET_SRC"/icon_256x256.png     "$ICONSET_TMP/icon_256x256.png"
    cp "$ICONSET_SRC"/icon_256x256@2x.png  "$ICONSET_TMP/icon_256x256@2x.png"
    cp "$ICONSET_SRC"/icon_512x512.png     "$ICONSET_TMP/icon_512x512.png"
    cp "$ICONSET_SRC"/icon_512x512@2x.png  "$ICONSET_TMP/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET_TMP" -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET_TMP")"
    echo "Icon installed: $RESOURCES_DIR/AppIcon.icns"
fi

# Overwrite the binary only — keep the bundle directory (and its inode/xattrs)
# stable so TCC keeps recognizing the app across rebuilds.
cp ".build/$CONFIGURATION/SwiftGrabApp" "$MACOS_DIR/$APP_NAME"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

# Pick signing identity.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    if [ "$CONFIGURATION" = "release" ]; then
        SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application:/ {print $2; exit}')"
    fi
    if [ -z "${SIGN_IDENTITY:-}" ]; then
        SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development:/ {print $2; exit}')"
    fi
    if [ -z "${SIGN_IDENTITY:-}" ]; then
        SIGN_IDENTITY="-"
    fi
fi

# Auto-enable hardened runtime when signing with Developer ID.
if [ -z "${HARDENED:-}" ]; then
    case "$SIGN_IDENTITY" in
        "Developer ID Application"*) HARDENED=1 ;;
        *) HARDENED=0 ;;
    esac
fi

SIGN_FLAGS=(--force --deep --timestamp --sign "$SIGN_IDENTITY")
if [ "$HARDENED" = "1" ]; then
    SIGN_FLAGS+=(--options runtime --entitlements "$ENTITLEMENTS")
fi

echo "Code signing ($SIGN_IDENTITY, hardened=$HARDENED)..."
codesign "${SIGN_FLAGS[@]}" "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
echo ""
echo "Run with:  open $APP_BUNDLE"
echo "Or:        $MACOS_DIR/$APP_NAME"
