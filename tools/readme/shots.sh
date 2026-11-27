#!/bin/bash
# README pictures from made-up data (demo-sets.json, demo.json): no real window titles.
# Builds a throwaway SpaceDock.app (English UI needs the bundle's translations) in a temp folder,
# renders the window with panel-shot into docs/readme/, and the hero animation (hero.swift) into
# docs/readme/hero.gif + dist/hero.mp4 (ffmpeg; the mp4 stays out of git).
set -euo pipefail
cd "$(dirname "$0")/../.."
TMP="$(mktemp -d)"
SPACEDOCK_OUT="$TMP" tools/make-app.sh >/dev/null
BIN="$TMP/SpaceDock.app/Contents/MacOS/spaces-layout"
DEMO=(-setsFile "$PWD/tools/readme/demo-sets.json" -shotDemo "$PWD/tools/readme/demo.json" -AppleLanguages "(en)" -shotNormal YES)
OUT=docs/readme
mkdir -p "$OUT" dist
for theme in light dark; do
    DARK=(); [ "$theme" = dark ] && DARK=(-shotDark YES)
    "$BIN" panel-shot "$OUT/window-$theme.png" 1100 400 "${DEMO[@]}" ${DARK[@]+"${DARK[@]}"}
    "$BIN" panel-shot "$OUT/preview-$theme.png" 1100 560 "${DEMO[@]}" -shotLayout 2 ${DARK[@]+"${DARK[@]}"}
done

swiftc -O tools/readme/hero.swift -o "$TMP/hero"
"$TMP/hero" "$TMP/frames" assets/icon/AppIcon-1024.png >/dev/null
ffmpeg -loglevel error -y -framerate 15 -i "$TMP/frames/frame-%04d.png" \
    -vf "scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff:max_colors=128[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
    -loop 0 "$OUT/hero.gif"
ffmpeg -loglevel error -y -framerate 15 -i "$TMP/frames/frame-%04d.png" -vf "scale=1600:-2" \
    -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart dist/hero.mp4
rm -rf "$TMP"
ls -la "$OUT"
