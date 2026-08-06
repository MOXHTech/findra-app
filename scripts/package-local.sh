#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-1.1.2}"
CONFIGURATION="${CONFIGURATION:-release}"
OUT_DIR="${OUT_DIR:-$ROOT/build}"
FINDRA_REPO="${FINDRA_REPO:-$ROOT/../findra}"
BUNDLE_DAEMON="${BUNDLE_DAEMON:-1}"
APP_DIR="$OUT_DIR/Findra.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VENDOR_BIN_DIR="$RESOURCES_DIR/vendor-bin"
ARCH="$(uname -m)"
BASE="Findra-${VERSION}-macos-${ARCH}"
DMG="$OUT_DIR/${BASE}.dmg"
ZIP="$OUT_DIR/${BASE}.zip"

cd "$ROOT"
swift build -c "$CONFIGURATION"

if [ "$BUNDLE_DAEMON" = "1" ]; then
  if [ ! -d "$FINDRA_REPO" ]; then
    printf 'findra repository not found at %s\n' "$FINDRA_REPO" >&2
    printf 'Set FINDRA_REPO=/path/to/findra or BUNDLE_DAEMON=0 for app-only packaging.\n' >&2
    exit 1
  fi
  (cd "$FINDRA_REPO" && cargo build --release -p findra-daemon)
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/$CONFIGURATION/Findra" "$MACOS_DIR/Findra"
if [ -f "$ROOT/Resources/Findra.icns" ]; then
  cp "$ROOT/Resources/Findra.icns" "$RESOURCES_DIR/Findra.icns"
fi
if [ -f "$ROOT/Resources/FindraIcon.png" ]; then
  cp "$ROOT/Resources/FindraIcon.png" "$RESOURCES_DIR/FindraIcon.png"
fi
if [ "$BUNDLE_DAEMON" = "1" ]; then
  mkdir -p "$VENDOR_BIN_DIR"
  cp "$FINDRA_REPO/target/release/findra-daemon" "$VENDOR_BIN_DIR/findra-daemon"
  chmod 755 "$VENDOR_BIN_DIR/findra-daemon"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Findra</string>
  <key>CFBundleExecutable</key>
  <string>Findra</string>
  <key>CFBundleIconFile</key>
  <string>Findra</string>
  <key>CFBundleIconName</key>
  <string>Findra</string>
  <key>CFBundleIdentifier</key>
  <string>com.findra.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Findra</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"
if [ -x "$VENDOR_BIN_DIR/findra-daemon" ]; then
  codesign --force --sign - "$VENDOR_BIN_DIR/findra-daemon"
fi
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$OUT_DIR"/Findra-*-macos-*.dmg "$OUT_DIR"/Findra-*-macos-*.dmg.sha256
rm -f "$OUT_DIR"/Findra-*-macos-*.zip "$OUT_DIR"/Findra-*-macos-*.zip.sha256
rm -f "$OUT_DIR"/Findra-*-macos-*.tar.gz "$OUT_DIR"/Findra-*-macos-*.tar.gz.sha256
ditto -c -k --keepParent "$APP_DIR" "$ZIP"

STAGE="$OUT_DIR/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP_DIR" "$STAGE/Findra.app"
ln -s /Applications "$STAGE/Applications"
diskutil image create from --format UDZO --volumeName "Findra $VERSION" "$STAGE" "$DMG"
rm -rf "$STAGE"

shasum -a 256 "$DMG" > "$DMG.sha256"
shasum -a 256 "$ZIP" > "$ZIP.sha256"

printf '%s\n' "$APP_DIR"
printf '%s\n' "$DMG"
printf '%s\n' "$ZIP"
