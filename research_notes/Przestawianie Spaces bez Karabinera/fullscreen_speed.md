# Speeding up "exit full screen, then re-enter full screen in order" for reordering Spaces (macOS 26 Tahoe / 27, Apple Silicon, SIP on)

Context: a new full-screen Space is appended at the end of its display's Spaces bar. Exiting full screen through remote-token AX elements is fast (0.2 s per window). The slow part is re-entering: after each window goes full screen, the system switches to the new Space, and a full-screen request for the next window, which now sits on a desktop that is no longer visible, is ignored. That costs 1.5–7 s per window; 5 moves took 22 s.

Research date: 2026-11-18. Most sources are community reverse-engineering (GitHub READMEs, issues, PRs), not Apple documentation. Private SkyLight behaviour changes between point releases (26.5 vs 26.6 vs 27.0.1), so treat every claim as version-specific.

## Instant Space switching tools (noswoosh, InstantSpaceSwitcher, iss, SpaceJumper, BTT, Reduce Motion, defaults): how they work and what still works on 26/27

### Takeaway
On 26/27 with SIP on, the working method is a **synthetic Dock-swipe gesture**: synthetic DockControl trackpad events with high velocity or full progress. The Dock then switches with no slide in about 100 ms. noswoosh, InstantSpaceSwitcher, iss and Quicker all use this. A second family of tools calls SkyLight **bridged** operations directly (SpaceJumper). Reduce Motion only swaps the slide for a crossfade of similar length. `expose-animation-duration` is gone from the 26.5 Dock binary. I found no evidence that `workspaces-swoosh-animation-off` exists on 26/27.

### Cited Findings
- **InstantSpaceSwitcher (jurplel):** creates "a synthetic trackpad gesture with an artificially high velocity", which skips the animation. It needs no SIP change, only Accessibility permission. The bundled CLI is `InstantSpaceSwitcher.app/Contents/MacOS/ISSCli --help`, and it installs with `brew install --cask jurplel/tap/instant-space-switcher`. The repo is active (104 commits, 30 open issues). One aggregator calls it archived; the GitHub page did not show that. — [GitHub jurplel/InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher); archived claim: [jurplel InstantSpaceSwitcher (aggregator)](https://hublens.pages.dev/en/jurplel-InstantSpaceSwitcher/)
- InstantSpaceSwitcher can "instantly jump to a space number". CLI usage is `[left|right|index <n>]`, so it is not limited to adjacent Spaces. The source article mentions only Tahoe and has no timing figures. — [arhan.sh: Native instant space switching on macOS](https://arhan.sh/blog/native-instant-space-switching-on-macos/)
- The same article on the alternatives: Reduce Motion "replaces it with an equally useless fade-in animation". The yabai scripting addition needs SIP disabled. instantspaces (flawnn) could not be made to work on Tahoe. BetterTouchTool has paid "Move Right/Left Space (Without Animation)" actions. — [arhan.sh](https://arhan.sh/blog/native-instant-space-switching-on-macos/)
- In the HN discussion, mort96 says Reduce Motion swaps the slide for a fade that takes about as long. aylmao says the animation is slower on 120 Hz displays. el_benhameen says input stays on the previous Space until the animation ends. modeless notes these fixes do not touch the full-screen enter/exit animation. — [Hacker News 47708818](https://news.ycombinator.com/item?id=47708818)
- **noswoosh (mmathys):** synthesizes a three-phase Dock-swipe gesture with near-zero progress and high velocity. Progress is `1e-4` on macOS 26 and `±0.1` on 27; near-zero progress on 27.0.1 left the destination black until Mission Control was opened. On 27 it attaches a serialized IOHID payload. A switch completes in **about 100 ms**. Supported on **26.6+ and 27**; 26.0–26.5 is not supported. No SIP change is needed. CLI: `noswoosh list|left|right|setup|teardown`. It deliberately does not disable `workspaces-auto-swoosh`, which would remove Dock-icon-follow. It may need "rearrange Spaces by most recent use" changed to get a predictable order. — [GitHub mmathys/noswoosh](https://github.com/mmathys/noswoosh)
- noswoosh issue #1 (Aug 2026), a detailed test matrix on 26.5.2:
  - A zero-duration synthetic swipe triggers a WindowServer surface-purge race: the destination shows only wallpaper and no windows.
  - A progress ramp over 40 ms has no wedge but shows a visible slide.
  - On 26.6.2 (Oct 1, 2026), the recipe Began ε → Changed ±1.0 → Ended ±1.0 at zero duration gave **0/24, 0/48 and 0/60 wedges, instant**.
  - A direct SLS switch (`SLSShowSpaces`/`SLSHideSpaces`/`SLSManagedDisplaySetCurrentSpace`, bracketed by `SLSManagedDisplaySetIsAnimating`) was instant and wedge-free but desynced Mission Control and window order. The Dock-internal `_currentSpace` cannot be synced from outside the Dock.
  - `expose-animation-duration` is "no longer present in the 26.5 Dock binary".
  - The `com.apple.private.dock.spaces` Mach service is entitlement-gated.
  - Full-screen Spaces, multiple displays and macOS 27 were untested for the direct-SLS path.
  — [noswoosh issue #1](https://github.com/mmathys/noswoosh/issues/1)
- **iss (joshuarli):** a session-level `CGEventTap` on private DockControl events. It suppresses the real horizontal 3-finger swipe and posts a synthetic sequence. On 27, posted events must carry a raw IOHID queue payload in serialized CGEvent **field 4205**; the boundary check via `CGSGetActiveSpace()` is skipped on 27 because that API "can lag behind the Dock". It claims macOS 26 and 27 support, with no SIP change and no injection. It does not mention full-screen Spaces. — [GitHub joshuarli/iss](https://github.com/joshuarli/iss)
- **SpaceJumper / InstantSpaces (alberti42):** switches through the bridged operations `SLSBridgedShowSpacesOperation`, `SLSBridgedManagedDisplaySetCurrentSpaceOperation` and `SLSBridgedHideSpacesOperation`. It says plain `SLSManagedDisplaySetCurrentSpace` does change the Space from a non-Dock app, but `SLSShowSpaces`/`SLSHideSpaces` are refused, "so windows from both Spaces remain on screen". With Reduce Motion on, it crossfades via `SLSNewTransition`/`SLSInvokeTransition`. It works with SIP on and loads no code into other processes. It requires macOS 15+, was tested on 27.0.1, and is "not yet tested on macOS 26". Multi-display is untested. — [GitHub alberti42/InstantSpaces](https://github.com/alberti42/InstantSpaces) (same content: [SpaceJumper](https://github.com/alberti42/SpaceJumper))
- **Quicker (pavlohuk)** also found that calling SLS from outside the Dock leaves the previous Space's windows on screen. — [GitHub pavlohuk/Quicker](https://github.com/pavlohuk/Quicker) (search snippet only, not fetched)
- **BetterTouchTool:** its "animationless desktop switch" first failed on full-screen Spaces. Build 5.507 (July 2025) fixed full-screen handling. With multiple displays, you must click a monitor before the no-animation switch acts on it. There is no "go to Space N" without animation in that thread. Only Sequoia 15.5 was tested. — [BTT community thread, p.2](https://community.folivora.ai/t/animationless-desktop-switch/44038?page=2)
- **Reduce Motion:** Apple says it "reduces movement when you open apps and switch desktops". Third-party sources say switching to a full-screen app crossfades instead of zooming. No source gives a measured duration. — [Apple Support: Reduce onscreen motion](https://support.apple.com/en-in/guide/mac-help/stop-or-reduce-onscreen-motion-mchlc03f57a1/14.0/mac); [Mainspring blog](https://trymainspring.com/blog/make-mac-feel-faster-reduce-motion)
- `expose-animation-duration` already had no effect on Mission Control or full-screen timing on Sierra (old report, outdated). — [mathiasbynens/dotfiles #711](https://github.com/mathiasbynens/dotfiles/issues/711)

### Inferences
- For the reorder pipeline, the fastest SIP-on way to return to the source desktop is `ISSCli index <n>` (jump to any index) or noswoosh/iss (adjacent only, about 100 ms). The full-progress Changed-phase recipe avoids blank windows on 26.6.x.
- Indices count all Spaces in the bar, including full-screen ones. After each full-screen entry the index of a given desktop does not change (the new Space is appended at the end), but compute it fresh from `SLSCopyManagedDisplaySpaces` before each jump.
- Reduce Motion is unlikely to save much time; it only replaces the slide with a fade.

### Gaps
- `defaults write com.apple.dock workspaces-swoosh-animation-off`: no source found confirming that this key exists or works on 15/26/27.
- `NSWindowResizeTime` and `NSToolbarFullScreenAnimationDuration`: only old blog/gist mentions. — [defaults-write.com](https://www.defaults-write.com/disable-full-screen-animation-of-os-x/), [gist j8](https://gist.github.com/j8/8ef9b6e39449cbe2069a). No evidence they affect full screen on 26/27; possibly outdated.
- No measured durations (in ms) for the Space switch or the full-screen transition, with or without Reduce Motion, on 26/27.

## Can SLSManagedDisplaySetCurrentSpace / SLSShowSpaces / SLSHideSpaces switch Spaces from a non-Dock process? (yabai, AeroSpace, Hammerspoon, FlashSpace, SpaceNamer, ShiftPlus)

### Takeaway
Yes, partly. `SLSManagedDisplaySetCurrentSpace` works from a normal process with SIP on, but plain Show/Hide are refused, which leaves stale windows on screen. The bridged `SLSBridged*Operation` variants are accepted. In every case the Dock's internal model desyncs: Mission Control state and window order go out of step.

### Cited Findings
- ShiftPlus (July 2026, tested on 15 and 26):
  - `SLSManagedDisplaySetCurrentSpace` is "the only write call" that still works with SIP on. It switches the active Space on a display.
  - On 15+ it does not fire `kCGSSpaceDidChange`, so the app sends a synthetic Dock swipe right and then left (net zero) to force a repaint.
  - Reads that work: `SLSCopyManagedDisplaySpaces`, `SLSCopySpacesForWindows`, `SLSManagedDisplayGetCurrentSpace`, `SLSSpaceGetType` (tells a desktop from a full-screen Space).
  — [ShiftPlus: macOS Spaces support without disabling SIP](https://shiftplus.app/blog/macos-spaces-without-disabling-sip/)
- SpaceNamer (verified on 26.5.2, 2026-07-18) switches with `CGSManagedDisplaySetCurrentSpace`, described as "direct, instant". It says AX press-to-switch through Mission Control is dead because the Dock exposes no Mission Control AX elements on 26. — [GitHub pakirman/SpaceNamer](https://github.com/pakirman/SpaceNamer)
- Show/Hide are refused from a non-Dock app, while the bridged operations are accepted. — [alberti42/InstantSpaces](https://github.com/alberti42/InstantSpaces)
- The direct SLS switch is instant, but the Mission Control and window-order desync is structural. — [noswoosh issue #1](https://github.com/mmathys/noswoosh/issues/1)
- **yabai:** space focus, move, swap, create and destroy require the scripting addition, which means partially disabling SIP. — [yabai wiki](https://github.com/koekeishiya/yabai/wiki), [Disabling SIP](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection)
- **Hammerspoon:** `hs.spaces.gotoSpace`, create and remove work through AX actions on the Dock's Mission Control (`MCwaitTime`), so they are slow and visible. — [hs.spaces docs](https://www.hammerspoon.org/docs/hs.spaces.html). This conflicts with SpaceNamer's claim that the Mission Control AX elements are not exposed on 26; that may depend on whether Mission Control is open.
- **AeroSpace and FlashSpace:** these are "virtual space facades" that hide and show windows instead of using native Spaces. — [arhan.sh](https://arhan.sh/blog/native-instant-space-switching-on-macos/)

### Inferences
- For the reorder script, the target desktop only needs to become active so that the Dock accepts the next full-screen request. Whether a SkyLight-only switch (Dock desynced) satisfies the Dock's full-screen logic is **unknown**: the Dock may believe it is still on the full-screen Space and ignore the request again. The synthetic-gesture route goes through the Dock, so the Dock's own model is updated. It is the safer choice for this use case.

### Gaps
- No source tests `SLSManagedDisplaySetCurrentSpace` immediately followed by AXFullScreen on 26/27.
- No source covers FlashSpace or Spaceman internals for native switching (not fetched).

## Toggling full screen without animation (AXFullScreen vs AXZoomButton vs menu vs Ctrl+Cmd+F, user defaults)

### Takeaway
I found no 2024–2026 evidence of any user default or API that removes or shortens the full-screen enter transition on 26/27, or of any difference between the AX trigger paths. The full-screen animation is outside what the space-switch tools address.

### Cited Findings
- HN (modeless): the instant-switch fixes "wouldn't address the slow animation when entering or leaving full screen". — [Hacker News 47708818](https://news.ycombinator.com/item?id=47708818)
- Old tweaks (`NSWindowResizeTime -float 0.001`, `NSToolbarFullScreenAnimationDuration 0`) come from the 10.9 era and, per their own comments, did not work even then. A MacRumors thread says full screen still animates with Finder `DisableAllAnimations`. Outdated. — [defaults-write.com](https://www.defaults-write.com/disable-full-screen-animation-of-os-x/); [gist j8](https://gist.github.com/j8/8ef9b6e39449cbe2069a); [MacRumors thread](https://forums.macrumors.com/threads/can-the-fullscreen-animation-be-disabled-or-speed-up.1417820/)
- With Reduce Motion on, the full-screen transition becomes a crossfade instead of a zoom (duration not measured). — [Mainspring blog](https://trymainspring.com/blog/make-mac-feel-faster-reduce-motion)
- WebKit: a full-screen window "remembers" the Space it was on the first time it entered full screen. The suggested workaround is `orderBack` before the transition (old, own-app API only). — [WebKit bug 135020](https://bugs.webkit.org/show_bug.cgi?id=135020)
- Mozilla: when several windows request full screen, nothing coordinates them, so one request can arrive during another window's transition. This supports the idea that requests must be serialized. — [Mozilla bug search result](https://bugzilla.mozilla.org/show_bug.cgi?id=1699666) (snippet only)

### Inferences
- Assume about 0.7–1 s per full-screen entry that cannot be removed. Speed comes from removing the wait for, or failure of, the Space switch, not from removing the full-screen animation.
- Poll for completion instead of waiting a fixed time: watch the count of Spaces with `SLSSpaceGetType` == full screen in `SLSCopyManagedDisplaySpaces` for that display, or the window's `AXFullScreen`.

### Gaps
- AXFullScreen vs `AXZoomButton` press vs the "Enter Full Screen" menu item vs Ctrl+Cmd+F: no source compares their behaviour or speed. This needs a local experiment.
- No source found for `NSAutomaticWindowAnimationsEnabled` or "NSWindowFullScreenAnimationDuration" affecting other apps' full screen on 26/27.

## Making a window on a hidden desktop enter full screen: moving it to the visible desktop first, or switching back

### Takeaway
There are two routes:
- **Move the window** to the visible desktop with `SLSBridgedMoveWindowsToManagedSpaceOperation`. Reports say this works on 26.4–26.7 with SIP on and fails on 27.0.1; SpaceNamer reports one variant dead on 26.5.2, so sources conflict.
- **Switch back** to the desktop instantly (synthetic gesture, about 100 ms) before each full-screen request.

### Cited Findings
- Direct `SLSMoveWindowsToManagedSpace` has been blocked for other apps' windows since 14.5. yabai's workaround (`SLSSpaceSetCompatID` with 0x79616265, then `SLSSetWindowListWorkspace`) is unreliable on Tahoe: `hs.spaces.moveWindowToSpace` returns true but the window stays put. — [Hammerspoon PR #3889](https://github.com/Hammerspoon/hammerspoon/pull/3889)
- Hammerspoon PR #3889 (opened Aug 16, 2026, not merged):
  - Calls `SLSPerformAsynchronousBridgedWindowManagementOperation` with an `SLSBridgedMoveWindowsToManagedSpaceOperation` instance, both resolved at runtime.
  - Tested on **26.5 (25F71)** and **26.6.2 (25G83)** with SIP on. Safari and Finder windows arrived "on the first 50 ms poll".
  - Full screen and Split View are untested.
  - Issue #3903 reports it still fails on **macOS 27.0.1**.
  — [Hammerspoon PR #3889](https://github.com/Hammerspoon/hammerspoon/pull/3889)
- spacemove sends `SLSBridgedMoveWindowsToManagedSpaceOperation` the `performWithWMBridgeDelegate` message, which goes to `WMClientWindowManager` and bypasses the `SLSWindowManagementClientOperationsEnabled()` gate. It says this needs 26.4+ and is "the one that works on 26.7". It has a fallback: hold the title bar and press "Switch to Desktop N". — [GitHub leeovery/spacemove](https://github.com/leeovery/spacemove)
- **Contradiction:** SpaceNamer reports that `SLSMoveWindowsToManagedSpace`, the compat route, `SLSAdd/RemoveWindowsTo/FromSpaces`, and **`SLSBridgedMoveWindowsToManagedSpaceOperation` with `invokeFallback`** all silently no-op on 26.5.2. — [SpaceNamer](https://github.com/pakirman/SpaceNamer). ShiftPlus says the non-bridged calls fail silently on 15 and 26. — [ShiftPlus](https://shiftplus.app/blog/macos-spaces-without-disabling-sip/). The likely difference is the invocation path (`invokeFallback` vs `SLSPerformAsynchronousBridged…` or `performWithWMBridgeDelegate`).
- `workspaces-auto-swoosh` (Dock, hidden key) controls whether activating an app whose window is on another Space switches to that Space. `defaults write com.apple.dock workspaces-auto-swoosh -bool NO; killall Dock` turns it off, and writing YES or `defaults delete` reverses it. Forum-level sources, mostly old. — [MacRumors thread](https://forums.macrumors.com/threads/cant-navigate-to-app-window-on-different-desktop-from-app-expose.2412161/); [Apple Community 4995042](https://discussions.apple.com/thread/4995042)

### Inferences
- **Recommended per-window loop (SIP on, 26.6.x)**, for windows that have exited full screen and sit on desktop D:
  1. Optional: bridged-move all windows to D first, if that works on your build.
  2. Before each window, ensure D is the current Space with `ISSCli index <idx(D)>` (synthetic gesture, about 0.1 s).
  3. Set `AXFullScreen=true` on the next window.
  4. Poll until a new full-screen Space appears.
  5. Repeat.

  Estimate: about 1–1.5 s per window (full-screen transition plus about 0.1 s switch-back plus poll slack), so **about 5–8 s for 5 windows instead of 22 s**. This is an extrapolation, not a measurement.
- Activating the target app (`NSRunningApplication.activate` or AXRaise) while `workspaces-auto-swoosh` is on (default) makes the Dock itself swoosh back to D, but with the normal animation. It is a fallback when synthetic gestures fail.
- On 27.0.1 the bridged move reportedly fails, so use only the switch-back route there.

### Gaps
- No source states which desktop a window lands on after exiting full screen on 26/27: its original desktop, or the current one.
- No source tests whether the full-screen request on a hidden-desktop window is merely ignored, or queued and then lost.

## Effect of "Displays have separate Spaces" and "Automatically rearrange Spaces based on most recent use" (mru-spaces)

### Takeaway
`mru-spaces` must be off, or the order you build gets shuffled. Toggling it is reversible. No source suggests that toggling either setting makes full-screen reordering faster.

### Cited Findings
- `defaults write com.apple.dock mru-spaces -bool false` disables automatic rearranging. — [macos-defaults: mru-spaces](https://macos-defaults.netlify.app/mission-control/mru-spaces.html)
- noswoosh notes that changing the "rearrange by most recent use" setting may be needed for a predictable switch order. — [noswoosh](https://github.com/mmathys/noswoosh)
- SpaceJumper: Space numbers can change while "Automatically rearrange Spaces" is on. — [alberti42/InstantSpaces](https://github.com/alberti42/InstantSpaces)
- ShiftPlus does not require mru-spaces off. Instead it visits Spaces from the highest index to the lowest during restore so the final order matches. — [ShiftPlus](https://shiftplus.app/blog/macos-spaces-without-disabling-sip/)

### Inferences
- Toggling "Displays have separate Spaces" needs a logout, and it collapses or rebuilds Spaces per display. It is not a practical speed-up; risky but reversible.

### Gaps
- No source on whether mru-spaces=true could reorder full-screen Spaces by visiting them in reverse order. That could avoid exit/re-enter entirely, but the order is effectively whatever was most recently used, so it is unreliable. Untested.

## Alternative workflows and tools for restoring Space order (maximized windows on fixed desktops, Split View, Stage Manager, tiling, restore apps)

### Takeaway
No tool found restores **full-screen Space order** natively. The tools restore windows onto desktops, either by switching Space and relaunching apps, or by bridged moves. Virtual-workspace managers (AeroSpace, FlashSpace) avoid native Spaces altogether and make order a config matter, with instant switching.

### Cited Findings
- **ShiftPlus:** never moves windows. It switches Space and relaunches the app so the new window opens on the active Space, deleting saved-state directories where needed (destructive to cosmetic state). — [ShiftPlus](https://shiftplus.app/blog/macos-spaces-without-disabling-sip/)
- **SpaceNamer:** launches apps that are not running onto their saved desktop by touring desktops in order. Windows on the wrong desktop must be dragged in Mission Control once. — [SpaceNamer](https://github.com/pakirman/SpaceNamer)
- **Many Displays:** on 14.5+ it cannot move windows between Spaces without SIP disabled. **Spencer:** restores take "a few seconds". **SnapState 2.7.2:** claims to restore windows and Spaces on wake or reconnect (no independent review). **DisplaySpacesManager:** users report it messing up the order. **Stay** and **memmon** handle window positions only. Apple feedback FB23070247 requests a public API for Spaces. — summarized from search results: [Many Displays](https://chatgate.ai/en/post/many-displays), [SnapState](https://www.hackingwithswift.com/forums/app-announcements/snapstate-2-7-2-puts-mac-windows-spaces-and-browser-tabs-back-after-sleep-or-a-dock-reconnect/31182), [BinaryAge forum](https://discuss.binaryage.com/t/spaces-on-external-monitors-are-swapped/3052), [Apple dev forums 830748](https://origin-devforums.apple.com/forums/thread/830748) (snippets, not fetched in full)
- **AeroSpace and FlashSpace:** virtual workspaces that hide and show windows. AeroSpace switches instantly but users report lost windows and a "windows in the corner" workaround. — [arhan.sh](https://arhan.sh/blog/native-instant-space-switching-on-macos/); [Hacker News 47708818](https://news.ycombinator.com/item?id=47708818)

### Inferences
- **"Maximized windows on fixed desktops"** avoids the append-at-end problem: desktop order stays stable across reconnects more often than full-screen order does. Windows can be bridged-moved to the right desktop on 26.4–26.6.x in about 50 ms each, then sized to the visible frame via AX. Not on 27.0.1. Desktops themselves can be reordered only by dragging in Mission Control.
- **AeroSpace or FlashSpace:** order is defined in config and switching is instant. This gives up native full-screen Spaces.

### Gaps
- Split View and Stage Manager as alternatives: no sources gathered on whether they keep or restore order.
- Moom, Display Maid, "Hookshot", "Workspaces", "SpaceSaver", "Spaceman" and FlashSpace internals: not researched in depth. Display Maid has only an App Store listing: [Display Maid](https://apps.apple.com/us/app/display-maid/id450063525).
