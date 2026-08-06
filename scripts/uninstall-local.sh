#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Findra.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP_PATH="$INSTALL_DIR/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

osascript -e 'tell application "Findra" to quit' >/dev/null 2>&1 &
QUIT_PID=$!
for _ in 1 2 3 4 5; do
  if ! kill -0 "$QUIT_PID" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
kill "$QUIT_PID" >/dev/null 2>&1 || true
pkill -x Findra >/dev/null 2>&1 || true
pkill -f "$APP_PATH/Contents/Resources/vendor-bin/findra-daemon" >/dev/null 2>&1 || true

if [ -d "$APP_PATH" ]; then
  [ -x "$LSREGISTER" ] && "$LSREGISTER" -u "$APP_PATH" >/dev/null 2>&1 || true
  rm -rf "$APP_PATH"
  printf 'removed %s\n' "$APP_PATH"
else
  printf 'not installed: %s\n' "$APP_PATH"
fi
