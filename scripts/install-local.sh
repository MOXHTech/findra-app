#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP_PATH="$INSTALL_DIR/Findra.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$ROOT/scripts/package-local.sh"
"$ROOT/scripts/uninstall-local.sh"

ditto "$ROOT/build/Findra.app" "$APP_PATH"
xattr -dr com.apple.quarantine "$APP_PATH" >/dev/null 2>&1 || true
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP_PATH" >/dev/null 2>&1 || true
rm -rf "$ROOT/build/Findra.app"
open -R "$APP_PATH"
printf 'installed %s\n' "$APP_PATH"
