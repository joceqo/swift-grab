#!/bin/bash
# Build a notarized, distributable DMG of SwiftGrab.
#
# Prerequisites (one-time):
#   1. Paid Apple Developer account.
#   2. "Developer ID Application" certificate installed in login keychain.
#      Download from https://developer.apple.com/account/resources/certificates
#   3. App-specific password generated at https://account.apple.com
#      (Sign-In and Security → App-Specific Passwords).
#   4. Store notary credentials once with:
#        xcrun notarytool store-credentials "swiftgrab-notary" \
#            --apple-id "you@example.com" \
#            --team-id "XXXXXXXXXX" \
#            --password "xxxx-xxxx-xxxx-xxxx"
#   5. brew install create-dmg
#
# Environment overrides:
#   VERSION         Semver tag baked into DMG filename (default: 1.0.0)
#   NOTARY_PROFILE  Keychain profile name from step 4 (default: swiftgrab-notary)
#   SIGN_IDENTITY   "Developer ID Application: ..." — auto-detected if unset
#   SKIP_NOTARIZE   1 to build+sign DMG without notarization (local testing)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="SwiftGrab"
VERSION="${VERSION:-1.0.0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-swiftgrab-notary}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

APP_BUNDLE="$PROJECT_DIR/.build/${APP_NAME}.app"
DMG_STAGING="$PROJECT_DIR/.build/dmg-staging"
DMG_OUT="$PROJECT_DIR/.build/${APP_NAME}-${VERSION}.dmg"

cd "$PROJECT_DIR"

# --- 1. Resolve Developer ID identity -----------------------------------------
if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application:/ {print $2; exit}')"
fi
if [ -z "${SIGN_IDENTITY:-}" ]; then
    echo "ERROR: no 'Developer ID Application' certificate in keychain." >&2
    echo "Install one from https://developer.apple.com/account/resources/certificates" >&2
    exit 1
fi
echo "==> Signing identity: $SIGN_IDENTITY"

# --- 2. Release build + signed app bundle -------------------------------------
echo "==> Building release app bundle..."
CONFIGURATION=release SIGN_IDENTITY="$SIGN_IDENTITY" HARDENED=1 \
    "$SCRIPT_DIR/build-app.sh"

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl --assess --type execute --verbose=2 "$APP_BUNDLE" || \
    echo "    (spctl warning — expected until notarization is stapled)"

# --- 3. Build DMG -------------------------------------------------------------
echo "==> Staging DMG contents..."
rm -rf "$DMG_STAGING" "$DMG_OUT"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

echo "==> Creating DMG..."
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 600 360 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 180 \
    --app-drop-link 450 180 \
    --hide-extension "${APP_NAME}.app" \
    "$DMG_OUT" \
    "$DMG_STAGING"

rm -rf "$DMG_STAGING"

echo "==> Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_OUT"

# --- 4. Notarize + staple -----------------------------------------------------
if [ "$SKIP_NOTARIZE" = "1" ]; then
    echo "==> SKIP_NOTARIZE=1 — leaving DMG unnotarized."
    echo "    Gatekeeper will warn on other machines."
    echo "Done: $DMG_OUT"
    exit 0
fi

echo "==> Submitting to Apple notary service (this can take several minutes)..."
xcrun notarytool submit "$DMG_OUT" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_OUT"
xcrun stapler validate "$DMG_OUT"

echo ""
echo "Done: $DMG_OUT"
echo "Signed, notarized, and stapled. Ready to distribute."
