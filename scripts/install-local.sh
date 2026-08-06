#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP_PATH="$INSTALL_DIR/Findra.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
WAS_RUNNING=0
if pgrep -x Findra >/dev/null 2>&1; then
  WAS_RUNNING=1
fi

"$ROOT/scripts/package-local.sh"
"$ROOT/scripts/uninstall-local.sh"

ditto "$ROOT/build/Findra.app" "$APP_PATH"
xattr -dr com.apple.quarantine "$APP_PATH" >/dev/null 2>&1 || true
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP_PATH" >/dev/null 2>&1 || true
touch "$APP_PATH"
mdimport "$APP_PATH" >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
rm -rf "$ROOT/build/Findra.app"
if [ "$WAS_RUNNING" = "1" ]; then
  open "$APP_PATH"
else
  open -R "$APP_PATH"
fi
printf 'installed %s\n' "$APP_PATH"
