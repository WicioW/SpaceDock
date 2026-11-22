# Private macOS APIs and system tricks for reordering Spaces, moving Spaces between displays and moving windows between Spaces (macOS 15 / 26 Tahoe / 27, Apple Silicon, SIP on)

Research date: 2026-11-18. Note on "local observation": some facts below were checked on this machine (macOS 27.0.1, build 26A434, arm64, SIP on) by enumerating ObjC classes in SkyLight with `objc_copyClassNamesForImage` and listing exports with `dyld_info -exports`. These were read-only checks: nothing was performed or invoked. They have no URL; they are marked **[local, read-only]**.

**Headline:** since macOS 26, SkyLight ships a family of ~90 `SLSBridged*Operation` classes, the "WMBridge". A normal AppKit process with SIP **on** can use them to move other apps' windows between Spaces (several projects confirm this), switch Spaces without animation, create and destroy Desktops (reports conflict), and **reorder Spaces or move them to another display** through `SLSBridgedMoveManagedSpaceToDisplayIndexOperation`. That last one is confirmed by one project and shipped by a second, but a third reports a Dock desync. It is the main candidate to test.

---

## Q1. How does yabai implement `space --move`, `space --display` and `window --space`? Can any part be used from outside the Dock without injection, and what works with SIP on in v7.x?

### Takeaway
`space --move`, `space --display` and `space --create/--destroy` still go only through the scripting addition (SA) injected into Dock. It calls Dock-internal `moveSpace`, `addSpace` and `removeSpace` functions, which it finds by byte-pattern scanning, so none of this can be called from outside Dock. `window --space` and `space --focus` **work with SIP on since yabai 7.1.25 and 7.1.19** (May and April 2026). They use the WMBridge operation and synthesized Dock-swipe gestures.

### Cited Findings
- The SA opcodes are `SPACE_FOCUS`, `SPACE_CREATE`, `SPACE_DESTROY`, `SPACE_MOVE`, `WINDOW_MOVE`, `WINDOW_LIST_TO_SPACE`, `WINDOW_TO_SPACE` and others. The handshake reports which Dock internals were found: `DOCK_SPACES`, `DPPM` (DesktopPictureManager), `ADD_SPACE`, `REM_SPACE`, `MOV_SPACE`, `SET_WINDOW`, `ANIM_TIME`. Messages go over a Unix socket `/tmp/yabai-sa_<user>.socket`. — [yabai src/osax/common.h](https://github.com/asmvik/yabai/blob/master/src/osax/common.h)
- `do_space_move` (in Dock). It resolves Dock's `dock_spaces` object and `move_space_fp` through `hex_find_seq` byte patterns (Dock-version specific). Sequence:
  1. If the moved Space is current, it runs `SLSShowSpaces([prev])`, `SLSHideSpaces([src])` and `SLSManagedDisplaySetCurrentSpace(display, prev)`, then sets the Dock ivar `_currentSpace`.
  2. `asm__call_move_space(source_space, dest_space, dest_display_uuid, dock_spaces, move_space_fp)` calls the Dock-internal moveSpace.
  3. On the main queue it calls `-[DesktopPictureManager moveSpace:toDisplay:displayUUID:]`.
  4. If focusing, it hides the destination Space, calls `SLSManagedDisplaySetCurrentSpace` and updates `_currentSpace` on the destination display.
  — [yabai src/osax/payload.m](https://github.com/asmvik/yabai/blob/master/src/osax/payload.m)
- `do_space_create` allocates `ManagedSpace` (Sequoia+) or `Dock.ManagedSpace` and calls the Dock-internal `addSpace` through `asm__call_add_space`. `do_space_destroy` calls the internal `removeSpace(space, display_space, dock_spaces, sid, sid)`. — [yabai payload.m](https://github.com/asmvik/yabai/blob/master/src/osax/payload.m)
- Host side, `space_manager_move_space_to_space` and `space_manager_move_space_to_display` call only `scripting_addition_move_space_after_space` / `scripting_addition_move_space_to_display`. There is no SIP-on fallback. — [yabai src/space_manager.c](https://github.com/asmvik/yabai/blob/master/src/space_manager.c)
- Window moves (`space_manager_move_window_to_space` / `_list_to_space`) try three paths in order:
  1. The bridged operation, if `SLSPerformAsynchronousBridgedWindowManagementOperation` is found:
     ```
     op = [[SLSBridgedMoveWindowsToManagedSpaceOperation alloc] initWithWindows:<NSArray of wid> spaceID:sid]
     SLSPerformAsynchronousBridgedWindowManagementOperation(op)
     ```
  2. Plain `SLSMoveWindowsToManagedSpace`, when no "macOS space workaround" is needed.
  3. Otherwise the SA, and if that fails, the compat-ID trick:
     ```
     SLSSpaceSetCompatID(cid, sid, 0x79616265)
     SLSSetWindowListWorkspace(cid, wids, n, 0x79616265)
     SLSSpaceSetCompatID(cid, sid, 0)
     ```
  — [yabai space_manager.c](https://github.com/asmvik/yabai/blob/master/src/space_manager.c)
- `SLSPerformAsynchronousBridgedWindowManagementOperation` has internal (static C++) linkage. yabai resolves the mangled local symbol `__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation` with `macho_find_symbol` (an LC_SYMTAB walk), because `dlsym` cannot see it. — [GitHub code search hit, yabai src/yabai.c](https://github.com/asmvik/yabai/blob/master/src/yabai.c); [floe docs](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md)
- `workspace_use_macos_space_workaround()` returns true for 12.7+, 13.6+, 14.5+ and all of 15+. — [yabai src/workspace.m](https://github.com/asmvik/yabai/blob/master/src/workspace.m)
- Changelog timeline:
  - 7.1.1 (2024-05): window moves fixed on 14.5.
  - 7.1.2 (2024-08): "Moving windows to other spaces requires SIP to be disabled on macOS Sequoia".
  - 7.1.16 (2025-10): preliminary Tahoe support.
  - 7.1.17 and 7.1.18: SA updated for 26.2, 26.3 and 26.4.
  - 7.1.19 (2026-04-18): "`space --focus` command now works with SIP enabled".
  - 7.1.21 to 7.1.23: SIP-on removal of the space-switch animation for cmd-tab and Dock clicks (`skip_window_focus_animation`).
  - **7.1.25 (2026-05-08): "Functionality for moving windows between spaces works with SIP enabled again"**.
  - Unreleased: SA `add_space` pattern fixed for 26.6.

  — [yabai CHANGELOG](https://github.com/asmvik/yabai/blob/master/CHANGELOG.md)
- yabai issue #2788. ejbills (DockDoor author): "You can do this without disabling SIP via `SLSBridgedMoveWindowsToManagedSpaceOperation` - validated working on macOS 26.4.1". The maintainer confirmed it on Tahoe 26.4. Known caveat: `window --space N --focus` conflicts with the animation-skip feature; the workaround is `window --space N; space --focus N`. — [yabai #2788](https://github.com/asmvik/yabai/issues/2788)
- yabai #2780. With SIP on, `space --focus` works "by synthesizing required gesture events" (high-velocity Dock swipe, idea from InstantSpaceSwitcher). On the macOS 27 RC ("golden gate") it broke with "cannot focus an already focused space". A later comment (2026-10-25) says the InstantSpaceSwitcher fix (jurplel/InstantSpaceSwitcher#103, #105) fixes it on macOS 27 with SIP on. It also notes yabai's `SUPPORTED_MACOS_VERSION_LIST` stops at Tahoe, so the `workspace_is_macos_*()` checks are false on 27. — [yabai #2780](https://github.com/asmvik/yabai/issues/2780)
- weft spike, macOS 26.5.2, yabai 7.1.25 with SA loaded: `space --create` and `--destroy` work. The old note "macOS 26.x can't make Desktops from the CLI" is stale. — [weft spikes/RESULTS.md](https://github.com/amiralibg/weft/blob/main/spikes/RESULTS.md)

### Inferences
- The Dock functions yabai's SA calls (`moveSpace`, `addSpace`, `removeSpace`, plus the `_currentSpace` ivar) live in Dock's private address space. They cannot be called from another process, so yabai's `space --move` logic is not reusable with SIP on. The WMBridge ops (Q2) appear to be Apple's own cross-process route to similar functionality, and have replaced the SA for window moves.
- yabai does not yet use `SLSBridgedMoveManagedSpaceToDisplayIndexOperation` for `space --move`. Nothing in the current source references it. So yabai is not evidence either way for SIP-on Space reordering.

### Gaps
- No yabai issue found that evaluates the bridged Space-move operation for `space --move` / `--display`.

---

## Q2. Which SkyLight/CGS private functions still work for third-party processes with SIP on (macOS 15 / 26 / 27)?

### Takeaway
On 15+, the **classic C functions are dead or no-ops for windows owned by other processes**. This covers SLSMoveWindowsToManagedSpace, SLSAdd/RemoveWindowsFromSpaces, SLSProcessAssignToSpace and the compat-ID trick (`SLSSetWindowListWorkspace` returns 1006 on 27). The working SIP-on surface on 26 and 27 is the **WMBridge**: `SLSBridged*Operation` objects dispatched with `-performWithWMBridgeDelegate`, with AppKit loaded in the process.

### Cited Findings: WMBridge (macOS 26+)
- **[local, read-only]** On macOS 27.0.1 (26A434), SkyLight contains among others:
  - Space layout: `SLSBridgedMoveManagedSpaceToDisplayIndexOperation (-initWithSpaceID:displayIdentifier:index:)`, `SLSBridgedSpaceCreateOperation (-initWithOptions:values:)`, `SLSBridgedSpaceDestroyOperation (-initWithSpaceID:)`, `SLSBridgedSpaceSetOrderingWeightOperation (-initWithSpaceID:weight:, Q,i)`.
  - Windows and processes: `SLSBridgedMoveWindowsToManagedSpaceOperation (-initWithWindows:spaceID:)`, `SLSBridgedAddWindowsToSpacesOperation`, `SLSBridgedRemoveWindowsFromSpacesOperation`, `SLSBridgedSpaceAddWindowsAndRemoveFromSpacesOperation (-initWithSpaceID:windows:options:)`, `SLSBridgedProcessAssignToSpaceOperation (-initWithProcess:spaceID:)`.
  - Switching: `SLSBridgedManagedDisplaySetCurrentSpaceOperation (-initWithDisplayIdentifier:spaceID:)`, `SLSBridgedShowSpacesOperation`, `SLSBridgedHideSpacesOperation`, `SLSBridgedWillSwitchSpacesOperation`, `SLSBridgedManagedDisplaySetIsAnimatingOperation`, `SLSBridgedSetSpaceManagementModeOperation`.
  - Tiling: `SLSBridgedSpaceTileMoveToSpaceAtIndexOperation (-initWithTileID:parentID:index:)`.

  The base classes `SLSAsynchronousBridgedWindowManagementOperation` and `SLSSynchronousBridgedWindowManagementOperation` have `-performWithWMBridgeDelegate` and `-invokeFallback` and conform to NSSecureCoding. `SLSWindowManagementFallbackBridge` (conforms to `SLSWindowManagementBridgeDelegate`) has `-performAsynchronousBridgedWindowManagementOperation:`, `-performSynchronousBridgedWindowManagementOperation:` and `-performWindowManagementBridgeTransactionUsingBlock:`. The C symbols `_SLSMoveManagedSpaceToDisplayIndex`, `_SLSSpaceCreate`, `_SLSSpaceDestroy`, `_SLSSpaceSetCompatID`, `_SLSSetWindowListWorkspace`, `_SLSSpaceSetOrderingWeight` are still exported.
- KiwiDesk on macOS 26.6.1 (25G76):
  - Dispatch is `[op performWithWMBridgeDelegate]`. "The process must have AppKit actually linked and loaded". A CLI that imports AppKit but references no AppKit symbol gets nil from every perform.
  - MoveWindowsToManagedSpace and ManagedDisplaySetCurrentSpace work.
  - Accessibility trust is **not** required for reads or writes.
  - SpaceCreate (options 0) "creates a REAL managed Desktop", and SpaceDestroy migrates windows.
  - AddWindowsToSpaces (sticky) works visually, but `CopySpacesForWindows` never reports multi-membership.
  - SpaceSetValues key/value data survives logout.
  - SpaceSetEdgeReservation: not demonstrated.

  — [KiwiDesk #884](https://github.com/KiwiCanopy/KiwiDesk/issues/884), [KiwiDesk #889](https://github.com/KiwiCanopy/KiwiDesk/issues/889)
- rift #404 (2026-07): Rust example using `performWithWMBridgeDelegate` for the move and query ops. — [acsandmann/rift #404](https://github.com/acsandmann/rift/issues/404)
- native-space-kit on macOS 27 RC (26A428), SIP on (most systematic source):
  - Dispatch: call `NSApplicationLoad()` and `[NSApplication sharedApplication]` first, then `performWithWMBridgeDelegate`. Sync ops are called as `id(*)(id,SEL)`, async ops as `void(*)(id,SEL)`. Async ops "can return before they apply", so poll for up to 2 s.
  - Verified: Create Desktop (`initWithOptions:0 values:@{}` creates a type-0 Desktop **appended at the end**), Destroy (windows go to the **active** Desktop), window moves, activation through the Show/Hide/SetCurrent triple, and **Reorder** (Q3).
  - "Not applied" for foreign windows: AddWindowsToSpaces and RemoveWindowsFromSpaces.

  — [native-space-kit docs/findings.md](https://github.com/Fjx-dylanZ/native-space-kit/blob/main/docs/findings.md)
- weft on macOS 27.0.1 (26A434):
  - Bridged move of another process's window: 6–15 ms, including across displays, and the user's current desktop does not change.
  - Batch move of 5 windows: 7.1 ms.
  - Bridged SpaceCreate: "Nothing observable is created".
  - Bridged AddWindowsToSpaces (sticky): refused.
  - `ManagedDisplaySetCurrentSpace` alone causes a desync. The triple `ShowSpaces([to])` + `HideSpaces([from])` + `SetCurrentSpace` gives "a clean switch in 16–21 ms … no animation", and the Dock agrees afterwards.
  - `SLSManagedDisplayIsAnimating` is never true.

  — [weft spikes/RESULTS.md, S10/S11](https://github.com/amiralibg/weft/blob/main/spikes/RESULTS.md)
- floe, on macOS 26.5.2 and rechecked on 27.0.1: the bridged window move works unchanged on 27.0.1. floe calls the static `SLSPerformAsynchronousBridgedWindowManagementOperation` found through an LC_SYMTAB walk. It claims the ops are "NSCoding objects that SkyLight forwards to the Dock, which executes them with its own WindowServer rights". — [floe docs/cgs-api-findings.md](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md)
- Hammerspoon PR #3889 (open, 2026-08): fixes `hs.spaces.moveWindowToSpace` on Tahoe with the bridged op, tested on 26.5 (25F71) with SIP on, including with yabai uninstalled. It says the compat-ID path "no longer performs the move reliably on Tahoe". — [Hammerspoon PR #3889](https://github.com/Hammerspoon/hammerspoon/pull/3889)
- Other adopters of the bridged window move, per a GitHub code search: Loop (`SkyLightBridgedSPI.swift`), DockDoor, WhichSpace (`WindowSpaceMove.c`), Dinky, spacepigeon, sunlight, mimi, openwork. — [GitHub code search results, e.g. mrkai77/Loop](https://github.com/mrkai77/Loop/blob/main/Loop/Private%20APIs/SkyLightBridgedSPI.swift), [gechr/WhichSpace](https://github.com/gechr/WhichSpace/blob/main/WhichSpace/Classes/WindowSpaceMove.c)

### Cited Findings: classic C functions
- weft S8, macOS 27.0 (26A428), SIP on, window of another process. **No movement** with any of these:
  - `SLSMoveWindowsToManagedSpace`, `SLSAddWindowsToSpaces` + `SLSRemoveWindowsFromSpaces`, `SLSSpaceAddWindowsAndRemoveFromSpaces`, `SLSReassociateWindowsSpacesByGeometry`, also with the owner's cid.
  - The transaction variants.
  - `SLSSpaceAddOwner`/`SetOwners` followed by a move.
  - The `SLSPackages…DraggingSpace` pipeline.
  - `SLSProcessAssignToSpace` and `SLSProcessAssignToAllSpaces` (these return 0 and do nothing).
  - `SLSSetWindowTags` (sticky).

  **`SLSSetWindowListWorkspace` returns 1006 (kCGErrorNotImplemented)**, so the compat-ID trick is dead on 27. "rc = 0 is a lie in this area." — [weft RESULTS.md S8](https://github.com/amiralibg/weft/blob/main/spikes/RESULTS.md)
- Spaceballs: the native move APIs "are blocked on macOS 14.5+ by `connection_holds_rights_on_window` checks". — [spaceballs AGENTS.md](https://github.com/moltenbits/spaceballs/blob/main/AGENTS.md)
- floe: `CGSAddWindowsToSpaces`/`RemoveWindowsFromSpaces` silently no-op on 15+ with SIP on. `CGSManagedDisplaySetCurrentSpace` alone only composites windows and does not really switch. Read-only calls (`CGSCopySpacesForWindows`, `CGSManagedDisplayGetCurrentSpace`) work. — [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md)

### Cited Findings: other tools
- Hammerspoon `hs.spaces.moveWindowToSpace`:
  - Broke in 14.5 ([#3636](https://github.com/Hammerspoon/hammerspoon/issues/3636), closed), then got the compat-ID workaround.
  - Broken again on 15 Sequoia ([#3698](https://github.com/Hammerspoon/hammerspoon/issues/3698), open).
  - Still broken on 27.0.1 in Hammerspoon 1.1.1 ([#3903](https://github.com/Hammerspoon/hammerspoon/issues/3903), 2026-10). A user there recommends building with franzbu's PR #3889 patch.
  - On macOS 27 the Mission Control AX tree moved from Dock to WindowManager ([#3897](https://github.com/Hammerspoon/hammerspoon/issues/3897)).
- floe's comparison table says Amethyst uses `CGSAddWindowsToSpaces`/`RemoveWindowsFromSpaces`, "degraded" on Sequoia (auto-follows to the target space, Amethyst #1713/#1701), and that AeroSpace emulates workspaces by moving windows off-screen without native Spaces. This is a secondary claim, not checked against the Amethyst source. — [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md)
- FlashSpace defines "virtual workspaces" made of app sets, as a replacement for native Spaces rather than a way to manipulate them. — [FlashSpace README](https://github.com/wojciech-kulik/FlashSpace)

### Inferences
- For a Space-layout tool on 26 and 27 with SIP on, plan around the WMBridge. Ignore the C functions, except read-only calls such as `SLSCopyManagedDisplaySpaces` and `SLSCopySpacesForWindows`.
- There are three dispatch routes in the wild:
  - `-[op performWithWMBridgeDelegate]`: KiwiDesk, rift, native-space-kit. Simplest, needs no symbol walk.
  - The static `SLSPerformAsynchronous/SynchronousBridgedWindowManagementOperation` found by LC_SYMTAB walk: yabai, floe, weft, Hammerspoon PR.
  - `[[SLSWindowManagementFallbackBridge alloc] init]` then `performAsynchronousBridgedWindowManagementOperation:op`: DesktopRenamer.

  Results may differ by route, which could explain the conflicting SpaceCreate and Space-move reports. Test with route 1 first.

### Gaps
- Which process executes the ops (Dock, or WindowManager on 27) is asserted by floe but was not verified from Apple code.
- No source found on whether `SLSBridgedProcessAssignToSpaceOperation` affects where an app's next windows open.
- No evidence for `SpaceSetOrderingWeight` semantics. It may be z-ordering and unrelated to Mission Control order.
- CGSSetConnectionProperty tricks, PaperWM.spoon, Spaceman, Rectangle Pro, Moom, "Spaces Renamer", DisplayMaid, "Workspaces" and "Stay" were not researched individually. No evidence found that any of them moves Spaces with SIP on. PaperWM.spoon and Drag.spoon use `mc.spaces.list` AX navigation ([code search](https://github.com/mogenson/PaperWM.spoon/blob/main/mission_control.lua)).

---

## Q3. Reordering Spaces and moving a Space to another display with SIP on, without injection

### Takeaway
Two working routes exist:
- **A. `SLSBridgedMoveManagedSpaceToDisplayIndexOperation`.** Verified on macOS 27 RC by native-space-kit, with Mission Control order matching. Shipped by DesktopRenamer since 2026-08/09, including fullscreen Spaces. floe reported a Dock desync on 26.5.2. Highest-priority test.
- **B. Synthetic mouse-drag automation of the Mission Control Spaces bar**, located by AX ids `mc.spaces.list`. Used in production by Spaceballs for Space-to-display moves on macOS 27. This is the "native", Dock-consistent path, but it is slow and timing-sensitive.

### Cited Findings
- native-space-kit §6, "Reordering (Verified)", macOS 27 RC, SIP on, one display, Desktops only:
  - `index` is the "**zero-based final position within the display**".
  - Swaps and moves gave the exact orders expected, and swapping the active Desktop kept it current.
  - "UUIDs, window membership, the current Space, and **Mission Control's thumbnail order matched the census** after every reorder".
  - A non-adjacent swap takes 2 ops and is not atomic.
  - Fullscreen or tile Spaces were not tested.

  §9: with a virtual second display, the op "with the other display's identifier **moved a Desktop to that display**". — [native-space-kit findings](https://github.com/Fjx-dylanZ/native-space-kit/blob/main/docs/findings.md)
- DesktopRenamer `SpaceRearrangementService.swift` ("Reorders spaces through macOS's private SkyLight operation"):
  1. `NSClassFromString("SLSBridgedMoveManagedSpaceToDisplayIndexOperation")`.
  2. Init through the IMP cast `(NSObject, SEL, UInt64 spaceID, NSString displayID, UInt32 destIndex)`, where `destIndex = src<tgt ? tgt-1 : tgt`.
  3. Dispatch with `[[SLSWindowManagementFallbackBridge alloc] init]` and `performAsynchronousBridgedWindowManagementOperation:`.
  4. Verify by polling every 0.35 s until the order is stable. When fullscreen Spaces are involved, it compares the full list including them.

  Commit history: "fix: remove unreliable space drag automation" → "feat: rearrange spaces through native skylight" (2026-08-21) → "feat: auto arrange fullscreen spaces" (2026-08-22). Releases: v1.14.0 (2026-09-09) "Drag-and-drop rearrangement for Spaces", "#158 Automatic arrangement of fullscreen Spaces". v1.14.0-beta.1: "Automatically position newly created fullscreen Spaces". v1.15.2: "#177 Move fullscreen desktops from the native launcher". — [DesktopRenamer source](https://github.com/gitmichaelqiu/DesktopRenamer/blob/main/DesktopRenamer/Services/Space/SpaceRearrangementService.swift), [releases](https://github.com/gitmichaelqiu/DesktopRenamer/releases)
- **Contradiction:** floe, macOS 26.5.2: "`SLSBridgedMoveManagedSpaceToDisplayIndexOperation` | WindowServer moves the space, **the Dock doesn't** — Mission Control keeps showing the old layout. Unusable." It also says "There is no Dock-consistent way to move a desktop to another display without injection". — [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md). weft tested the op only on a bogus Space id: "nothing". — [weft S11](https://github.com/amiralibg/weft/blob/main/spikes/RESULTS.md)
- KiwiDesk catalogued `MoveManagedSpaceToDisplayIndexOperation` as "reorder / cross-display" but did not probe it. — [KiwiDesk #884](https://github.com/KiwiCanopy/KiwiDesk/issues/884)
- Spaceballs, Mission Control drag route (macOS 27 target):
  - Moves whole Spaces between displays by dragging Space tiles in `mc.spaces.list` with CGEvent `leftMouseDown`/`Dragged`/`Up`.
  - Sequence: hover the bar so it expands, wait for confirmed expansion, grab, nudge **downward** out of the bar ("in-bar motion reads as reordering"), homing drag to the destination bar's center, dwell about 0.6 s, drop, wait about 0.5 s for the commit.
  - The active Space cannot be dragged; switch away first.
  - On macOS 27 the MC AX tree lives in `com.apple.WindowManager` (from 27.2 the Dock exposes no `mc` group). Tile `AXPosition` is the tile's **center**. The bar starts collapsed and expands on hover.
  - Batches several drags in one MC session.
  - Final position in the destination bar is not guaranteed.

  — [spaceballs README](https://github.com/moltenbits/spaceballs/blob/main/README.md), [AGENTS.md](https://github.com/moltenbits/spaceballs/blob/main/AGENTS.md)
- floe/Hammerspoon: Mission Control AX ids `mc` → `mc.display` → `mc.spaces` → `mc.spaces.list` (desktop buttons with the `AXRemoveDesktop` action) and `mc.spaces.add`. Usable to add or remove desktops while keeping the Dock consistent. — [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md), [Hammerspoon spaces.lua](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/spaces/spaces.lua)
- Apple's "Work in multiple spaces on Mac" guide (macOS 27) documents moving windows to another Space by dragging in Mission Control or to the screen edge. It does **not** document reordering Spaces. — [Apple Support mh14112](https://support.apple.com/guide/mac-help/mh14112/mac). Reordering by dragging thumbnails, including full-screen apps, is described by third parties. — [MacPaw](https://macpaw.com/how-to/use-mission-control-mac), [O'Reilly](https://www.oreilly.com/library/view/switching-to-the/9781491955055/ch04s12.html)
- Hammerspoon #3669 "Reordering Spaces" (2024): no API. The user fell back to **swapping window contents** between Spaces with `moveWindowToSpace`. — [Hammerspoon #3669](https://github.com/Hammerspoon/hammerspoon/issues/3669)
- Content-swap route on 26 and 27: the bridged window move takes an array, 5 windows in 7.1 ms ([weft S11](https://github.com/amiralibg/weft/blob/main/spikes/RESULTS.md)). Owners of fullscreen Spaces cannot be moved like this. native-space-kit refuses windows associated with the fullscreen owner, while guest windows (e.g. Siri) can leave a fullscreen Space. — [native-space-kit §5](https://github.com/Fjx-dylanZ/native-space-kit/blob/main/docs/findings.md)

### Inferences
- The floe vs native-space-kit conflict may come from version (26.5.2 vs 27 RC), dispatch route (static perform function vs `performWithWMBridgeDelegate`) or how Mission Control was checked. DesktopRenamer ships the op to a 133-star user base and handles fullscreen Spaces, which suggests it works on at least some 26.x/27 builds. Test on this Mac, 27.0.1:
  1. A reorder of two normal Desktops.
  2. A reorder that crosses a fullscreen Space.
  3. Moving a fullscreen Space.

  After each, check `SLSCopyManagedDisplaySpaces`, the Mission Control thumbnails, Ctrl-arrow navigation order, and the state after `killall Dock`.
- A window-content swap cannot reorder fullscreen Spaces, because their owner window cannot be moved to a Desktop. For fullscreen apps, reordering has to use route A or B, or the user's existing AXFullScreen re-entry approach.

### Gaps
- No independent confirmation of whether `MoveManagedSpaceToDisplayIndex` order survives a Dock restart or logout. A PKGSpaceAssignmentController class with `recordManagedSpaceOrder:forManagedDisplayID:` exists in SkyLight **[local, read-only]**, which hints that WindowServer persists the order, but this was not verified.
- No source tested `MoveManagedSpaceToDisplayIndex` on fullscreen Spaces, apart from DesktopRenamer's release notes and code paths.

---

## Q4. Making Dock/WindowManager re-read Space order (plist, `mru-spaces`, `spans-displays`), and XPC/Mach services that accept Space-management requests

### Takeaway
No plist or `defaults` route reorders Spaces. Your own tests showed Dock rebuilds from WindowServer. The only "service" route found is the WMBridge, a designed NSSecureCoding operation surface that SkyLight forwards. No public reports were found of talking to Dock or WindowManager over raw XPC.

### Cited Findings
- WMBridge ops conform to NSCoding/NSSecureCoding, have typed result classes and carry `invokeFallback`: "a designed, versioned surface … not scattered C symbols". — [KiwiDesk #884](https://github.com/KiwiCanopy/KiwiDesk/issues/884). floe claims SkyLight forwards them to the Dock. — [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md)
- macOS 27 moved the Mission Control UI from Dock into the WindowManager process. — [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md), [Hammerspoon #3897](https://github.com/Hammerspoon/hammerspoon/issues/3897), [spaceballs AGENTS.md](https://github.com/moltenbits/spaceballs/blob/main/AGENTS.md)
- Bridged `SpaceSetValuesOperation` writes custom keys into a Space's WindowServer dictionary (`kiwidesk.*` next to `WindowManagerInfo`). They persist across logout, but a Space on a secondary display dies on unplug. On reconnect a fresh Desktop is created and the ids churn. — [KiwiDesk #889](https://github.com/KiwiCanopy/KiwiDesk/issues/889)
- Even with "Automatically rearrange Spaces based on most recent use" off, a community report says Spaces are still rearranged when an app enters or leaves full screen (Apple Community thread, via search snippet; not official). — [Apple Community 8506252](https://discussions.apple.com/thread/8506252)

### Inferences
- `mru-spaces` should be set to false so the system does not undo a programmatic order, but it does not reorder anything by itself.

### Gaps
- No evidence about `spans-displays` interaction with the bridged ops. KiwiDesk notes only that the display identifier is `"Main"` in shared mode and per-display UUIDs in separate mode ([#889](https://github.com/KiwiCanopy/KiwiDesk/issues/889)).
- No public reverse-engineering of a Dock or WindowManager XPC/Mach service for Space management was found.

---

## Q5. Creating a full-screen Space through a private API with a chosen insert position, and suppressing the automatic switch or animation

### Takeaway
No source shows a way to create a **fullscreen** (type 4) Space at a chosen index. Bridged `SpaceCreate` makes ordinary Desktops, appended at the end, or does nothing, depending on the report. The practical pattern is **create, then reposition**: DesktopRenamer's "Automatically position newly created fullscreen Spaces" does this with `MoveManagedSpaceToDisplayIndex`. To avoid the switch animation, the strongest candidate is the **bridged Show/Hide/SetCurrent triple** (instant, about 15–30 ms, works into and out of a fullscreen Space on 27.0.1). The next is a high-velocity synthetic Dock swipe.

### Cited Findings
- Bridged `SpaceCreateOperation`:
  - native-space-kit, 27 RC: options 0 gives a type-0 Desktop "appended after the existing Desktops in every trial". No placement options are known. Options 1 gives an unmanaged type-3 "overlay" Space that does not appear in the census.
  - KiwiDesk, 26.6.1: creates a real Desktop.
  - weft, 27.0.1: nothing observable.
  - floe, 26.5.2: a Space id not attached to any display.

  — [native-space-kit](https://github.com/Fjx-dylanZ/native-space-kit/blob/main/docs/findings.md), [KiwiDesk #889](https://github.com/KiwiCanopy/KiwiDesk/issues/889), [weft](https://github.com/amiralibg/weft/blob/main/spikes/RESULTS.md), [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md)
- DesktopRenamer v1.14.0-beta.1: "Automatically position newly created fullscreen Spaces". v1.14.0: "#158 Automatic arrangement of fullscreen Spaces". Its rearrangement service handles fullscreen Space ids in the expected order. — [DesktopRenamer releases](https://github.com/gitmichaelqiu/DesktopRenamer/releases), [source](https://github.com/gitmichaelqiu/DesktopRenamer/blob/main/DesktopRenamer/Services/Space/SpaceRearrangementService.swift)
- weft Spike 4, 27.0.1, two displays: the triple works on the second display and with a fullscreen Space in the list. Results: "fullscreen 425 → desktop 1" in 31.5 ms with no trace of the fullscreen app; 76 → 81 across a fullscreen Space in 28 ms; back into the fullscreen Space in 13.7 ms; the Dock stays in sync. — [weft RESULTS.md](https://github.com/amiralibg/weft/blob/main/spikes/RESULTS.md)
- native-space-kit: activation through the triple shows "no slide animation" in a screen recording. — [native-space-kit §4](https://github.com/Fjx-dylanZ/native-space-kit/blob/main/docs/findings.md)
- Dock-swipe route:
  - Post `kCGSEventDockControl` with `kIOHIDEventTypeDockSwipe`, a Began/Ended pair and velocity ±9999, which switches one Space instantly. Needs Accessibility trust.
  - On macOS 27, WindowServer drops a synthetic swipe unless it carries an IOHIDEvent (field 4205) plus a companion type-29 gesture event.
  - Overshooting past the last desktop wedges the Dock (black screen).

  — [floe](https://github.com/Buecherfresser/floe/blob/main/docs/cgs-api-findings.md), [yabai #2780](https://github.com/asmvik/yabai/issues/2780), [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher)
- yabai `skip_window_focus_animation` (7.1.22+, SIP on) pre-activates the target Space when an app front-switch or window-focus event fires. It covers cmd-tab and Dock clicks, not fullscreen creation. — [yabai #2781](https://github.com/asmvik/yabai/issues/2781)
- A `SLSBridgedManagedDisplaySetIsAnimatingOperation` exists, but is untested. — [KiwiDesk #884](https://github.com/KiwiCanopy/KiwiDesk/issues/884)

### Inferences
- For the current ~1.5 s/space AXFullScreen re-entry cost, the test candidate is:
  1. Toggle AXFullScreen.
  2. As soon as the new type-4 Space appears in `SLSCopyManagedDisplaySpaces`, run the bridged triple back to the original Space, which may cut the zoom-in animation short.
  3. Then `MoveManagedSpaceToDisplayIndex` the new Space into place.

  Better still, if route A works for fullscreen Spaces, skip re-entering fullscreen and just reorder the existing fullscreen Spaces.

### Gaps
- No source on creating a type-4 (fullscreen) Space directly, or on `-[NSWindow toggleFullScreen:]` on remote windows.
- Nobody reports interrupting the native enter-fullscreen animation with the triple. It is unknown whether the triple during the transition is safe or leaves the app in a broken fullscreen state.
