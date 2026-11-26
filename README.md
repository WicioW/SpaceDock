# SpaceDock

SpaceDock remembers the order of your Spaces (full-screen apps and desktops) for every set of
monitors, and puts them back after you plug or unplug a display.

macOS shuffles Spaces when monitors come and go: full-screen apps end up on the wrong display or
at the end of the bar. SpaceDock keeps saved layouts per monitor set ("Laptop only",
"Laptop + DELL", …) and restores the selected one automatically, or when you click **Restore**.

- Menu bar app with a window that shows the saved layouts, monitor by monitor
- Several named layouts per monitor set ("Work", "Evening", …): pick one in the window, the menu
  bar or with a shortcut (e.g. ⌃⌥1–9), and SpaceDock rearranges your Spaces to match
- Optionally hides full-screen apps that are not in the layout (minimized, never quit)
- Tells two windows of the same app apart (e.g. two browser windows) by window and title
- English, Polish, Spanish, Simplified Chinese

## Requirements

- macOS 15 or later. The fast restore method needs macOS 26 or later; on older systems
  SpaceDock falls back to a slower method.
- The **Accessibility** permission (the **Grant Permission…** button in SpaceDock's window).

## Install

1. Download `SpaceDock-<version>.dmg` from [Releases](../../releases) and drag `SpaceDock.app`
   to `/Applications`.
2. Open it. SpaceDock is not notarized by Apple, so macOS blocks the first launch. Go to
   **System Settings → Privacy & Security** and click **Open Anyway**. Or, in Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/SpaceDock.app
   ```
3. Click **Grant Permission…** in SpaceDock's window and turn SpaceDock on in
   System Settings → Privacy & Security → Accessibility.
4. Arrange your Spaces, click **Save Current Layout** and name the layout. Do this once for every monitor set;
   add more layouts with **Save as New…**.

Or with [Homebrew](https://brew.sh) (step 2 still applies):
```bash
brew tap wiciow/spacedock
brew trust wiciow/spacedock
brew install --cask spacedock
```

Updates come inside the app: once a day SpaceDock checks the latest GitHub release and offers to
install a newer version (or **Check for Updates…** in the menu). Updates are signed, install
without the Open Anyway step and keep the Accessibility permission.

## Restore methods

Settings → **Method**:

| Method | How | Speed |
|---|---|---|
| **Direct** (default) | Moves each Space straight to its place and display through a private macOS 26+ window-management operation. No mouse, no Mission Control. | ~0.1 s per Space |
| Drag | Drags thumbnails in Mission Control with a virtual mouse. Needs [Karabiner-Elements](https://karabiner-elements.pqrs.org) and a root helper (see `docs/app.md`). | ~1.2 s per Space |
| Full Screen | Takes windows out of full screen and back in the saved order (a new full-screen Space always goes to the end of the bar). | ~1.5–5 s per Space |

If Direct fails, SpaceDock tries Drag, then Full Screen.

## Privacy

Everything stays on your Mac. Layouts are in
`~/Library/Application Support/SpaceDock/layout-sets.json` (`layouts.json` from versions before 0.3), the log in
`~/Library/Logs/SpaceDock.log`. Saved layouts contain app names and window titles (a
browser window's title is its open tab). The log has app names and window numbers, no titles,
so it is safe to attach to a bug report. The only network request is the daily update check: it
downloads `appcast.xml` from this repository's latest release (turn it off in Settings).

## Caveats

SpaceDock uses private macOS APIs (SkyLight) to read and move Spaces. A macOS update can break
them; SpaceDock then falls back to the slower methods.

## Build from source

```bash
tools/make-app.sh && open ~/Applications/SpaceDock.app
```

Signing with your own code-signing certificate keeps the Accessibility permission across
rebuilds: create one in Keychain Access (Certificate Assistant → Create a Certificate, type
"Code Signing") and pass its name:

```bash
SPACEDOCK_SIGN_IDENTITY="My Code Signing" tools/make-app.sh
```

Command-line tools for debugging (`list`, `save`, `restore-bridge`, `spmove`, …) run with the
app's permission through `tools/run-in-app.sh <command>`. Design notes and experiments (in
Polish): `docs/app.md`, `docs/experiments.md`.

## License

[PolyForm Noncommercial 1.0.0](LICENSE): you may read, change and use SpaceDock for any
noncommercial purpose (personal use, study, hobby projects, charities, schools). Selling it or
using it commercially needs the author's permission: open an issue.

Bundled third-party parts keep their own licenses: [Sparkle](https://sparkle-project.org) (MIT),
the fonts in `assets/fonts` (SIL Open Font License, texts next to them).
