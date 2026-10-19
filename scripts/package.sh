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

echo "==> Building DiskScope ($CONFIG, universal arm64 + x86_64)"
xcodebuild \
  -project DiskScope.xcodeproj \
  -scheme DiskScope \
  -configuration "$CONFIG" \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  clean build

if [[ ! -d "$APP" ]]; then
  echo "Build product not found: $APP" >&2
  exit 1
fi

ARCHS_FOUND="$(lipo -archs "$APP/Contents/MacOS/DiskScope" 2>/dev/null || true)"
if [[ "$ARCHS_FOUND" != *"arm64"* || "$ARCHS_FOUND" != *"x86_64"* ]]; then
  echo "error: expected a universal binary, got: ${ARCHS_FOUND:-unknown}" >&2
  exit 1
fi
echo "    binary architectures: $ARCHS_FOUND"

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
mkdir -p "$STAGE/.background"
cp "$ROOT/docs/dmg-background.png" "$STAGE/.background/background.png"

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
  VOLUME_NAME="$(basename "$MOUNT_DIR")"
  # Finder window: background picture, icon size and icon positions.
  # This is what makes the DMG open with a drag-to-Applications guide.
  if ! osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {300, 160, 960, 608}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 100
    set background picture of viewOptions to (POSIX file "$MOUNT_DIR/.background/background.png" as alias)
    set position of item "DiskScope.app" of container window to {170, 210}
    set position of item "Applications" of container window to {490, 210}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
  then
    echo "warning: Finder layout step failed; the DMG is still usable" >&2
  fi

  # Set the custom volume icon after Finder has rewritten the folder flags.
  # Finder may remove .VolumeIcon.icns while arranging the window, so copy it
  # back before marking the volume.
  cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
  sync
  sleep 1
  hdiutil detach "$MOUNT_DIR" -quiet
fi

hdiutil convert "$RW" -format UDZO -o "$DMG" -ov >/dev/null
rm -f "$RW"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

echo "==> Done"
echo "$DMG"
