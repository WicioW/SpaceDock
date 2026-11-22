#!/bin/sh
# Homebrew cask for a published release, in the tap github.com/WicioW/homebrew-spacedock:
#   tools/update-cask.sh 0.1.1             write dist/spacedock.rb only
#   tools/update-cask.sh 0.1.1 --publish   also put it in the tap as Casks/spacedock.rb (gh api)
# release.sh --publish runs it. Users install with: brew install --cask wiciow/spacedock/spacedock
# The checksum comes from the release on GitHub, so the cask matches what is really published.
set -e
cd "$(dirname "$0")/.."
VERSION="$1"
TAP="${SPACEDOCK_TAP:-WicioW/homebrew-spacedock}"
[ -n "$VERSION" ] || { echo "Użycie: tools/update-cask.sh <wersja> [--publish]"; exit 1; }
SHA="$(curl -fsSL "https://github.com/WicioW/SpaceDock/releases/download/v$VERSION/SpaceDock-$VERSION.dmg.sha256" | awk '{ print $1 }')"
[ ${#SHA} = 64 ] || { echo "Brak sumy SHA-256 dla v$VERSION na GitHubie"; exit 1; }

mkdir -p dist
cat > dist/spacedock.rb <<RUBY
cask "spacedock" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/WicioW/SpaceDock/releases/download/v#{version}/SpaceDock-#{version}.dmg"
  name "SpaceDock"
  desc "Saves full-screen Spaces per monitor set and restores them"
  homepage "https://github.com/WicioW/SpaceDock"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sequoia

  app "SpaceDock.app"

  zap trash: [
    "~/Library/Application Support/SpaceDock",
    "~/Library/Caches/io.github.wiciow.spacedock",
    "~/Library/HTTPStorages/io.github.wiciow.spacedock",
    "~/Library/HTTPStorages/io.github.wiciow.spacedock.binarycookies",
    "~/Library/Logs/SpaceDock.log",
    "~/Library/Preferences/io.github.wiciow.spacedock.plist",
  ]

  caveats <<~EOS
    SpaceDock is not notarized by Apple. On first launch macOS says it can't verify the app:
    click Done, then System Settings → Privacy & Security → Open Anyway.
  EOS
end
RUBY
echo "Cask: dist/spacedock.rb ($VERSION)"

if [ "$2" = "--publish" ]; then
    FILE="repos/$TAP/contents/Casks/spacedock.rb"
    OLD="$(gh api "$FILE" --jq .sha 2>/dev/null || true)"   # empty for the first version
    ID="$(gh api user --jq .id)"; LOGIN="$(gh api user --jq .login)"
    # Committer set explicitly: the noreply address, never the account's real email.
    gh api -X PUT "$FILE" --silent \
        -f message="spacedock $VERSION" \
        -f content="$(base64 < dist/spacedock.rb | tr -d '\n')" \
        ${OLD:+-f sha="$OLD"} \
        -f "committer[name]=$LOGIN" -f "committer[email]=$ID+$LOGIN@users.noreply.github.com"
    echo "Tap: https://github.com/$TAP/blob/HEAD/Casks/spacedock.rb"
fi
