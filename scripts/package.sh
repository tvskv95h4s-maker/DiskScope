#!/usr/bin/env bash
#
# Build a Release app and package it as a DMG.
# Usage: ./scripts/package.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-Release}"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Build/Products/$CONFIG/DiskScope.app"

echo "==> Building DiskScope ($CONFIG)"
xcodebuild \
  -project DiskScope.xcodeproj \
  -scheme DiskScope \
  -configuration "$CONFIG" \
  -derivedDataPath "$BUILD_DIR" \
  build

if [[ ! -d "$APP" ]]; then
  echo "Build product not found: $APP" >&2
  exit 1
fi

# Optional Developer ID signing for notarized releases:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package.sh
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "==> Signing with $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
STAGE="$BUILD_DIR/dmg-stage"
DMG="$ROOT/dist/DiskScope-$VERSION.dmg"

echo "==> Staging DiskScope $VERSION"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$ROOT/dist"
ditto "$APP" "$STAGE/DiskScope.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/docs/INSTALL.txt" "$STAGE/Read Me.txt"

echo "==> Creating DMG"
rm -f "$DMG"
RW="$BUILD_DIR/DiskScope-rw.dmg"
rm -f "$RW"
hdiutil create \
  -volname "DiskScope $VERSION" \
  -srcfolder "$STAGE" \
  -ov -format UDRW \
  "$RW"

# Give the volume the app icon in Finder.
MOUNT_DIR="$(hdiutil attach -nobrowse -readwrite "$RW" | tail -1 | awk -F '\t' '{print $NF}')"
if [[ -d "$MOUNT_DIR" ]]; then
  cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
  sync
  hdiutil detach "$MOUNT_DIR" -quiet
fi

hdiutil convert "$RW" -format UDZO -o "$DMG" -ov >/dev/null
rm -f "$RW"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

echo "==> Done"
echo "$DMG"
