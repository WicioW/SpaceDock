#!/bin/sh
# Builds a release in dist/: universal SpaceDock.app (Apple Silicon + Intel) signed with the
# SpaceDock certificate, SpaceDock-<version>.zip and .dmg (drag to Applications) with SHA-256 sums,
# and appcast.xml for in-app updates (Sparkle; the zip signed with the EdDSA key in the Keychain).
#   tools/release.sh 0.1.0             build only
#   tools/release.sh 0.1.0 --publish   also create GitHub release v0.1.0 with gh (public!)
# Every release must be signed with the same certificate, or users lose the Accessibility
# permission on update, so an ad-hoc signature is refused here.
set -e
cd "$(dirname "$0")/.."
VERSION="$1"
[ -n "$VERSION" ] || { echo "Użycie: tools/release.sh <wersja> [--publish]"; exit 1; }
IDENTITY="${SPACEDOCK_SIGN_IDENTITY:-SpaceDock}"
security find-certificate -c "$IDENTITY" >/dev/null 2>&1 || { echo "Brak certyfikatu \"$IDENTITY\" (docs/app.md)"; exit 1; }
# Without the update key the app would ship without an updater, and its users would stay on it.
[ -s assets/sparkle-public-key.txt ] || { echo "Brak assets/sparkle-public-key.txt (docs/app.md, aktualizacje)"; exit 1; }
SIGN_UPDATE=.build/sparkle-tools/bin/sign_update
[ -x "$SIGN_UPDATE" ] || { echo "Brak $SIGN_UPDATE (docs/app.md, aktualizacje)"; exit 1; }
# Where the app downloads this version from; SPACEDOCK_DOWNLOADS for local tests.
DOWNLOADS="${SPACEDOCK_DOWNLOADS:-https://github.com/WicioW/SpaceDock/releases/download/v$VERSION}"

rm -rf dist
SPACEDOCK_OUT="$PWD/dist" SPACEDOCK_VERSION="$VERSION" SPACEDOCK_UNIVERSAL=1 tools/make-app.sh
APP=dist/SpaceDock.app
codesign --verify --strict "$APP"
codesign -dvv "$APP" 2>&1 | grep -q "Authority=$IDENTITY" || { echo "Podpis nie jest \"$IDENTITY\""; exit 1; }
echo "Architektury: $(lipo -archs "$APP/Contents/MacOS/spaces-layout")"

ZIP="dist/SpaceDock-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"   # ditto keeps the signature intact (zip may not)
(cd dist && shasum -a 256 "SpaceDock-$VERSION.zip" > "SpaceDock-$VERSION.zip.sha256")
cat "$ZIP.sha256"

DMG="dist/SpaceDock-$VERSION.dmg"
tools/make-dmg.sh "$APP" "$DMG" "SpaceDock $VERSION"   # shuttle background, first-launch steps
(cd dist && shasum -a 256 "SpaceDock-$VERSION.dmg" > "SpaceDock-$VERSION.dmg.sha256")
cat "$DMG.sha256"

# One item, the newest version: every older version updates straight to it.
SIGNATURE="$("$SIGN_UPDATE" --account spacedock "$ZIP")"   # sparkle:edSignature="…" length="…"
cat > dist/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>SpaceDock</title>
    <item>
      <title>SpaceDock $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/WicioW/SpaceDock/releases/tag/v$VERSION</sparkle:fullReleaseNotesLink>
      <enclosure url="$DOWNLOADS/SpaceDock-$VERSION.zip" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
XML
echo "Appcast: dist/appcast.xml"

if [ "$2" = "--publish" ]; then
    # The same DMG under a name that never changes: …/releases/latest/download/SpaceDock.dmg
    # (website, README, posts) always gets the newest version.
    cp "$DMG" dist/SpaceDock.dmg
    NOTES="**Install:** download \`SpaceDock-$VERSION.dmg\` below and drag SpaceDock to Applications. SpaceDock is not notarized: the first time, open System Settings → Privacy & Security and click **Open Anyway**. Homebrew: \`brew tap wiciow/spacedock && brew trust wiciow/spacedock && brew install --cask spacedock\`.

**Update:** SpaceDock offers this version on its own (or menu bar → Check for Updates…).

Requires macOS 15 or later. Website: https://wiciow.github.io/SpaceDock/"
    gh release create "v$VERSION" "$ZIP" "$ZIP.sha256" "$DMG" "$DMG.sha256" dist/SpaceDock.dmg dist/appcast.xml \
        --title "SpaceDock $VERSION" --notes "$NOTES" --generate-notes
    tools/update-cask.sh "$VERSION" --publish   # Homebrew: brew install --cask wiciow/spacedock/spacedock
fi
