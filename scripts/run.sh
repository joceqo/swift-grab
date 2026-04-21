#!/bin/bash
# Build the signed .app bundle and launch it.
# Use this instead of `swift run SwiftGrabApp` — the CLI binary path changes
# on every rebuild, which invalidates the Accessibility permission grant.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

"$SCRIPT_DIR/build-app.sh"

# Kill any running instance so the rebuilt binary launches fresh.
pkill -x SwiftGrab 2>/dev/null || true

open "$PROJECT_DIR/.build/SwiftGrab.app"
