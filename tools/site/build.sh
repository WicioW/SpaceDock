#!/bin/sh
# Assembles the website (site/ plus the README pictures and the app icon) into one folder.
#   tools/site/build.sh <out>    e.g. _site (GitHub Actions) or a temp folder for a local preview
# The pictures live in docs/readme/ (tools/readme/shots.sh renders them), so the site never keeps
# its own copies that could drift.
set -e
cd "$(dirname "$0")/../.."
OUT="${1:?Użycie: tools/site/build.sh <folder>}"
rm -rf "$OUT"
mkdir -p "$OUT/img"
cp site/index.html site/404.html "$OUT/"
touch "$OUT/.nojekyll"
cp docs/readme/hero.gif docs/readme/window-light.png docs/readme/window-dark.png \
   docs/readme/preview-light.png docs/readme/preview-dark.png docs/readme/social.png "$OUT/img/"
sips -z 256 256 assets/icon/AppIcon-1024.png --out "$OUT/img/icon.png" >/dev/null 2>&1 || cp assets/icon/AppIcon-1024.png "$OUT/img/icon.png"
echo "Strona: $OUT"
