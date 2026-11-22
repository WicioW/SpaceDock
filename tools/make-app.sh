#!/bin/sh
# Builds and installs ~/Applications/SpaceDock.app: the same binary in a bundle, so it starts
# as the window app (no Dock icon, menu bar icon only).
# Signed with a local code-signing certificate (docs/app.md) so the Accessibility grant survives
# rebuilds; without it ad-hoc, and the grant is lost on every rebuild. Its name comes from
# SPACEDOCK_SIGN_IDENTITY (default "SpaceDock", the certificate releases are signed with).
# For tools/release.sh: SPACEDOCK_OUT (folder for the .app, default ~/Applications, where it also
# replaces the running app), SPACEDOCK_VERSION, SPACEDOCK_UNIVERSAL=1 (Apple Silicon + Intel).
# Updates (Sparkle): SPACEDOCK_FEED overrides the appcast URL (local tests); the public EdDSA key
# is read from assets/sparkle-public-key.txt, and without it the app has no updater.
set -e
cd "$(dirname "$0")/.."
IDENTITY="${SPACEDOCK_SIGN_IDENTITY:-SpaceDock}"
OUT="${SPACEDOCK_OUT:-$HOME/Applications}"
VERSION="${SPACEDOCK_VERSION:-0.1}"
FEED="${SPACEDOCK_FEED:-https://github.com/WicioW/SpaceDock/releases/latest/download/appcast.xml}"
UPDATE_KEY="$(cat assets/sparkle-public-key.txt 2>/dev/null || true)"
if [ "$SPACEDOCK_UNIVERSAL" = 1 ]; then
    # Command Line Tools have no multi-arch `swift build`: two builds (own scratch paths, they
    # would overwrite each other), one binary with lipo.
    for arch in arm64 x86_64; do
        swift build -c release --triple "$arch-apple-macosx15.0" --scratch-path ".build/$arch"
    done
    mkdir -p .build/universal
    lipo -create -output .build/universal/spaces-layout \
        "$(swift build -c release --triple arm64-apple-macosx15.0 --scratch-path .build/arm64 --show-bin-path)/spaces-layout" \
        "$(swift build -c release --triple x86_64-apple-macosx15.0 --scratch-path .build/x86_64 --show-bin-path)/spaces-layout"
    BIN=.build/universal/spaces-layout
else
    swift build -c release
    BIN=.build/release/spaces-layout
fi
APP="$OUT/SpaceDock.app"
mkdir -p "$OUT"
if [ "$OUT" = "$HOME/Applications" ]; then
    pkill -f "Applications/.*\.app/Contents/MacOS/spaces-layout" || true
    rm -rf "$OUT/Spaces Layout.app" "$OUT/SpaceShips.app"   # earlier names of the app
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/spaces-layout"
mkdir -p "$APP/Contents/Resources"
cp assets/icon/AppIcon.icns assets/icon/MenuBarIconTemplate.png assets/icon/MenuBarIconTemplate@2x.png "$APP/Contents/Resources/"
cp -R Localization/*.lproj "$APP/Contents/Resources/"   # UI translations; the Polish source text is the key
mkdir -p "$APP/Contents/Resources/Fonts"
cp assets/fonts/*.ttf assets/fonts/*-OFL.txt "$APP/Contents/Resources/Fonts/"   # the panel look's fonts and their licenses
mkdir -p "$APP/Contents/Frameworks"   # Sparkle keeps its own signature (no hardened runtime, so no library validation)
SPARKLE="$(find .build -type d -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -prune | head -1)"   # universal; any scratch path
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.wiciow.spacedock</string>
    <key>CFBundleName</key><string>SpaceDock</string>
    <key>CFBundleDisplayName</key><string>SpaceDock</string>
    <key>CFBundleDevelopmentRegion</key><string>pl</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleExecutable</key><string>spaces-layout</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>SUFeedURL</key><string>$FEED</string>
    <key>SUEnableAutomaticChecks</key><true/>
$( [ -n "$UPDATE_KEY" ] && echo "    <key>SUPublicEDKey</key><string>$UPDATE_KEY</string>" )
</dict>
</plist>
PLIST
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    codesign --force -s "$IDENTITY" "$APP"
else
    echo "Brak certyfikatu \"$IDENTITY\": podpis ad-hoc, uprawnienie Dostępność zniknie po przebudowie"
    codesign --force -s - "$APP"
fi
echo "Gotowe: $APP"
