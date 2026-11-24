#!/bin/sh
# Builds a DMG whose window shows SpaceDock and Applications on the shuttle background with the
# first-launch steps (Sources/DMGBackground.swift):
#   tools/make-dmg.sh <SpaceDock.app> <out.dmg> <volume name>
# The window layout lives in the image's .DS_Store, which only Finder writes: macOS asks once
# whether the terminal may control Finder (System Settings → Privacy & Security → Automation).
set -e
cd "$(dirname "$0")/.."
APP="$1"; OUT="$2"; VOL="$3"
[ -d "$APP" ] && [ -n "$OUT" ] && [ -n "$VOL" ] || { echo "Użycie: tools/make-dmg.sh <app> <out.dmg> <nazwa woluminu>"; exit 1; }
[ -d "/Volumes/$VOL" ] && { echo "Wolumin \"$VOL\" jest już zamontowany, wysuń go najpierw"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src/.background"
ditto "$APP" "$WORK/src/SpaceDock.app"
ln -s /Applications "$WORK/src/Applications"
swift build -c release >/dev/null
.build/release/spaces-layout dmg-background "$WORK"
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/src/.background/background.tiff" >/dev/null 2>&1

# Read-write image first (Finder writes the layout into it), then compressed. diskutil image, not
# hdiutil (deprecated, see man hdiutil); its blank images offer no HFS+, APFS is fine from macOS 10.13.
diskutil image create blank --format RAW --size 60m --volumeName "$VOL" -fs APFS "$WORK/rw.dmg" >/dev/null
DEV="$(diskutil image attach "$WORK/rw.dmg" | awk '/^\/dev\// { print $1; exit }')"   # whole image, e.g. /dev/disk7
ditto "$WORK/src" "/Volumes/$VOL"
# Icon centers and window size: DMGLayout in Sources/DMGBackground.swift (640 × 400).
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 552}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 96
        set text size of opts to 13
        set background picture of opts to file ".background:background.tiff"
        set position of item "SpaceDock.app" of container window to {150, 150}
        set position of item "Applications" of container window to {490, 150}
        set extension hidden of item "SpaceDock.app" to true
        -- hidden files: out of the window for whoever shows them in Finder
        try
            set position of item ".background" of container window to {900, 150}
        end try
        update without registering applications
        delay 1
        set the bounds of container window to {200, 120, 840, 552}
        delay 1
        close
    end tell
end tell
APPLESCRIPT
rm -rf "/Volumes/$VOL/.fseventsd"
sync
diskutil eject "$DEV" >/dev/null
rm -f "$OUT"
diskutil image create from --format UDZO "$WORK/rw.dmg" "$OUT" >/dev/null
