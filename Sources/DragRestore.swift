import AppKit

// `restore-drag`: second restore variant. Instead of leaving and re-entering full screen,
// it drags thumbnails in Mission Control's Spaces bar with Karabiner's virtual mouse
// (the only input Mission Control accepts on macOS 27, see docs/experiments.md T21–T25).
// Works across monitors: every display has its own bar, but Mission Control takes input only on
// the display it was opened from (T35), so a drag between bars does not take. A Space on the
// wrong display is moved the slow way (out of full screen, onto that display, full screen
// again), then each display's bar is ordered by drags in its own Mission Control session.
// Desktops are ordered too (saved as "desktop" entries), but never moved between displays.

/// Longest run of `seq` that is already increasing (O(n²), n is a handful of Spaces).
func longestIncreasing(_ seq: [Int]) -> Set<Int> {
    guard !seq.isEmpty else { return [] }
    var len = [Int](repeating: 1, count: seq.count), prev = [Int](repeating: -1, count: seq.count)
    for i in seq.indices {
        for j in 0..<i where seq[j] < seq[i] && len[j] + 1 > len[i] { len[i] = len[j] + 1; prev[i] = j }
    }
    var i = len.indices.max { len[$0] < len[$1] }!, out: Set<Int> = []
    while i >= 0 { out.insert(seq[i]); i = prev[i] }
    return out
}

/// Next drag: Spaces already in the right relative order stay; the first misplaced one (in
/// target order) goes right after its target predecessor. Each drag grows the kept run by
/// one, so the total is `count - longest in-order run` drags.
func nextMove(cur: [Int], target: [Int]) -> (item: Int, after: Int?)? {
    guard cur != target else { return nil }
    let pos = Dictionary(uniqueKeysWithValues: target.enumerated().map { ($1, $0) })
    let keep = longestIncreasing(cur.compactMap { pos[$0] })
    guard let i = target.indices.first(where: { !keep.contains($0) }) else { return nil }
    return (target[i], i > 0 ? target[i - 1] : nil)
}

/// display UUID -> Space IDs in bar order (full-screen and desktops)
typealias Bars = [String: [Int]]

/// Saved layout turned into the wanted Space IDs per display: saved entries matched by bundle
/// ID in order (a Space already on that display first, so two windows of one app do not swap
/// displays; desktops only on their own display). Unsaved desktops go first (where macOS
/// keeps them, and all of them for a save made before desktops were saved), unsaved apps last.
struct LiveSpace: Equatable {
    let id: Int
    let bundle: String          // desktopID for a desktop
    var window: CGWindowID? = nil
    var title = ""
}

/// Which live Space goes to each saved place. Strongest evidence first, over all saved places,
/// so a weak match never takes a Space a stronger one needs: same window, then same app and
/// window title (the window was reopened, e.g. after a restart), then same app on the same
/// display, then same app anywhere. Desktops only match on their own display.
func targetLayout(current: [String: [LiveSpace]], saved: [String: [Entry]]) -> Bars {
    let (pick, pool) = matchSpaces(current: current, saved: saved)
    var target = Bars(uniqueKeysWithValues: current.keys.map { d in (d, (saved[d] ?? []).indices.compactMap { pick[d]?[$0] }) })
    for p in pool.reversed() where p.space.bundle == desktopID { target[p.display]!.insert(p.space.id, at: 0) }
    for p in pool where p.space.bundle != desktopID { target[p.display]!.append(p.space.id) }
    return target
}

/// The matching behind `targetLayout`: display → saved index → Space ID, plus the live Spaces
/// no saved place took (not in the save).
func matchSpaces(current: [String: [LiveSpace]], saved: [String: [Entry]])
    -> (pick: [String: [Int: Int]], rest: [(display: String, space: LiveSpace)]) {
    var pool = current.keys.sorted().flatMap { d in current[d]!.map { (display: d, space: $0) } }
    let places = saved.keys.sorted().filter { current[$0] != nil }.flatMap { d in saved[d]!.indices.map { (d, $0) } }
    let rules: [(Entry, String, (display: String, space: LiveSpace)) -> Bool] = [
        // Window numbers are reused after a restart, by any app: same number counts only within the app.
        { e, _, p in e.window != nil && p.space.window == e.window && p.space.bundle == e.bundleID },
        { e, _, p in !e.isDesktop && !e.title.isEmpty && p.space.bundle == e.bundleID && p.space.title == e.title },
        { e, d, p in p.display == d && p.space.bundle == e.bundleID },
        { e, _, p in !e.isDesktop && p.space.bundle == e.bundleID },
    ]
    var pick: [String: [Int: Int]] = [:]   // display → saved index → Space ID
    for rule in rules {
        for (d, i) in places where pick[d]?[i] == nil {
            if let j = pool.firstIndex(where: { rule(saved[d]![i], d, $0) }) { pick[d, default: [:]][i] = pool.remove(at: j).space.id }
        }
    }
    return (pick, pool)
}

enum TileMark { case none, unsaved, missing }

struct Tile {
    let entry: Entry
    let mark: TileMark
}

/// What the window shows for a connected set: per display the saved places in saved order
/// (`missing` when no Space on the bar matched), and each Space not in the save (`unsaved`)
/// where it is now: right after the saved place whose Space stands before it on the bar, or
/// first. `describe` names a live Space.
func layoutDiff(saved: Layout, live: [String: [LiveSpace]], describe: (LiveSpace) -> Entry) -> [String: [Tile]] {
    let (pick, rest) = matchSpaces(current: live, saved: saved)
    let unsaved = Set(rest.map(\.space.id))
    var out: [String: [Tile]] = [:]
    for d in Set(saved.keys).union(live.keys) {
        let place = Dictionary(uniqueKeysWithValues: (pick[d] ?? [:]).map { ($0.value, $0.key) })   // Space ID → saved index
        var after: [Int: [LiveSpace]] = [:]   // saved index (-1 = first) → unsaved Spaces behind it, in bar order
        var anchor = -1
        for s in live[d] ?? [] {
            if let i = place[s.id] { anchor = i } else if unsaved.contains(s.id) { after[anchor, default: []].append(s) }
        }
        func extra(_ i: Int) -> [Tile] { (after[i] ?? []).map { Tile(entry: describe($0), mark: .unsaved) } }
        out[d] = extra(-1) + (saved[d] ?? []).indices.flatMap { i in
            [Tile(entry: saved[d]![i], mark: pick[d]?[i] == nil ? .missing : .none)] + extra(i)
        }
    }
    return out
}

/// AX titles of the full-screen windows by window number. Read once per restore: AX is slow,
/// and a title that changes mid-restore doesn't matter.
func liveTitles() -> [CGWindowID: String] {
    var out: [CGWindowID: String] = [:]
    for s in liveDisplays().flatMap(\.spaces) {
        if let pid = s.pid, let id = s.windowID, let w = axWindow(pid: pid, id: id) { out[id] = title(w) }
    }
    return out
}

/// Next drag across displays: first Spaces that sit on the wrong display (dropped after the
/// nearest earlier target Space already on that bar), then the order inside each bar.
/// `after` nil = before the bar's first full-screen Space.
func nextMove(cur: Bars, target: Bars) -> (item: Int, display: String, after: Int?)? {
    let home = Dictionary(uniqueKeysWithValues: cur.flatMap { d, ids in ids.map { ($0, d) } })
    for d in target.keys.sorted() {
        let t = target[d]!
        if let i = t.firstIndex(where: { home[$0] != d }) {
            return (t[i], d, t[..<i].last { home[$0] == d })
        }
    }
    for d in target.keys.sorted() {
        if let m = nextMove(cur: cur[d] ?? [], target: target[d]!) { return (m.item, d, m.after) }
    }
    return nil
}

enum DragResult { case done, noMouse, failed }

/// Space IDs per display, live.
func liveBars() -> Bars {
    Bars(uniqueKeysWithValues: liveDisplays().map { ($0.uuid, $0.spaces.map(\.id)) })
}

/// Each display's bar in Mission Control with its thumbnails, left to right, paired with
/// that display's Spaces (SkyLight order = bar order).
private func barsOnScreen() -> [String: (bar: CGRect, thumbs: [(id: Int, frame: CGRect)])] {
    let monitors = activeMonitors(), displays = liveDisplays()
    var out: [String: (bar: CGRect, thumbs: [(id: Int, frame: CGRect)])] = [:]
    for list in spacesLists() {
        guard let bar = frame(list),
              let m = monitors.first(where: { $0.bounds.contains(CGPoint(x: bar.midX, y: bar.midY)) }),
              let d = displays.first(where: { $0.uuid == m.uuid }) else { continue }
        let thumbs = children(list).compactMap(frame).sorted { $0.minX < $1.minX }
        guard thumbs.count == d.spaces.count else { continue }
        out[d.uuid] = (bar, zip(d.spaces.map(\.id), thumbs).map { ($0, $1) })
    }
    return out
}

/// One drag in an open Mission Control: Space `item` into display `display`'s bar, right
/// after Space `after` (nil = before the first full-screen Space there).
var debugBarY: CGFloat? = nil   // mcmove: y below the bar's top instead of its middle

// Thumbnail positions come from the row's geometry, not from each thumbnail's AX frame: the
// row is centered on the display's bar, one thumbnail per AX pitch (192 pt here). A screenshot
// (T39) showed the real centers exactly there, while the AX frames sat half a thumbnail to the
// right (so pressing at their middle hit the edge, and missed now and then) and in some sessions
// a whole thumbnail to the left.
// ponytail: centering model checked on one 4K and one 1440p display; re-check if a bar ever scrolls.
private func centers(_ bar: (bar: CGRect, thumbs: [(id: Int, frame: CGRect)])) -> [CGFloat] {
    let t = bar.thumbs.map(\.frame), n = CGFloat(t.count)
    let pitch = t.count > 1 ? t[1].minX - t[0].minX : 192
    return t.indices.map { bar.bar.midX + (CGFloat($0) - (n - 1) / 2) * pitch }
}

/// Did the drag put `item` where the move wanted it (right after `after`, or first)?
func placed(_ item: Int, after: Int?, in bar: [Int]) -> Bool {
    guard let after else { return bar.first == item }
    guard let a = bar.firstIndex(of: after), a + 1 < bar.count else { return false }
    return bar[a + 1] == item
}

/// After a drag that missed: how many thumbnails off the grab was, from what actually moved.
/// One drag moves one Space, so the moved one is the Space whose removal leaves both bars equal;
/// its old index minus the intended one is the error. Nothing moved = the press hit a gap
/// between thumbnails (seen on the laptop bar with the DELL connected): half a thumbnail.
// ponytail: a gap hit does not tell which side; +0.5 first, the fallback restore covers a 2nd miss.
func aimError(before: [Int], after: [Int], intended: Int) -> CGFloat {
    guard before != after, let i = before.firstIndex(of: intended) else { return 0.5 }
    let moved = before.first { m in before.filter { $0 != m } == after.filter { $0 != m } }
    return moved.flatMap { before.firstIndex(of: $0) }.map { CGFloat($0 - i) } ?? 0.5
}

/// Aim correction per display in thumbnails, learned from misses during one restore.
var aimNudge: [String: CGFloat] = [:]
/// Where the last drag aimed, for the log when it misses.
var lastAim = ""

private func dragSpace(_ item: Int, to display: String, after: Int?, mouse: MouseHelper) -> Bool {
    let bars = barsOnScreen()
    guard let src = bars.values.first(where: { $0.thumbs.contains { $0.id == item } }),
          let i = src.thumbs.firstIndex(where: { $0.id == item }),
          let dst = bars[display] else { print("✗ nie widzę paska albo miniaturki \(item)"); return false }
    let pitch = { (c: [CGFloat]) in c.count > 1 ? c[1] - c[0] : 192 }
    let srcDisplay = bars.first { $0.value.thumbs.contains { $0.id == item } }?.key ?? display
    let from = centers(src)[i] + aimNudge[srcDisplay, default: 0] * pitch(centers(src))
    let c = centers(dst).map { $0 + aimNudge[display, default: 0] * pitch(centers(dst)) }, ids = dst.thumbs.map(\.id)
    let half = pitch(c) / 2
    lastAim = String(format: "x=%.0f (pasek środek %.0f, szer. %.0f, odstęp %.0f, miniatur %d, indeks %d, poprawka %+.1f)",
                     from, src.bar.midX, src.bar.width, pitch(centers(src)), src.thumbs.count, i, aimNudge[srcDisplay, default: 0])
    // Drop into the gap after `after` (dropping on a thumbnail merges both into Split View).
    let gap = after.flatMap { ids.firstIndex(of: $0) }.map { c[$0] + half } ?? (c.first ?? dst.bar.midX) - half
    let y1 = debugBarY.map { src.bar.minY + $0 } ?? src.bar.midY, y2 = debugBarY.map { dst.bar.minY + $0 } ?? dst.bar.midY
    return mouse.send("drag \(from) \(y1) \(gap) \(y2)")
}

/// Opens Mission Control from `display` (it takes input only there) with the virtual mouse
/// hovering its bar (bars expand only under real cursor movement), runs `body`, closes it.
private func inMissionControl(_ mouse: MouseHelper, on display: String?, _ body: () -> DragResult) -> DragResult {
    let screen = activeMonitors().first { $0.uuid == display }?.bounds ?? activeMonitors().first?.bounds ?? .zero
    mouse.send("move \(screen.midX) \(screen.midY)")
    openMissionControl()
    defer { if spacesList() != nil { openMissionControl() } } // toggles it closed; synthetic Esc is ignored
    guard waitUntil(timeout: 2, { !spacesLists().isEmpty }) else { print("Mission Control się nie otworzył"); return .failed }
    mouse.send("move \(screen.midX) \(screen.minY + 20)")
    // Expanded bar is much taller than the collapsed name strip (170–188 vs 40–72 pt).
    waitUntil(timeout: 1) { spacesLists().allSatisfy { (frame($0)?.height ?? 0) > 100 } }
    Thread.sleep(forTimeInterval: 0.15) // expansion animation
    return body()
}

/// Moves a full-screen Space onto another display: out of full screen, window onto that display,
/// full screen again. The new Space lands at the end of that display's bar.
private func moveToDisplay(_ spaceID: Int, _ display: String) -> Bool {
    guard let s = liveDisplays().flatMap(\.spaces).first(where: { $0.id == spaceID }), let pid = s.pid,
          let bounds = activeMonitors().first(where: { $0.uuid == display })?.bounds, goTo(spaceID),
          let w = axWindows(pid: pid).first(where: { windowID($0) == s.windowID }), setFullScreen(w, false) else { return false }
    waitUntil { !liveDisplays().flatMap(\.spaces).contains { $0.id == spaceID } }
    Thread.sleep(forTimeInterval: 0.05)
    let t = Taken(bundleID: bundleID(pid) ?? "?", title: title(w), window: w, id: s.windowID, pid: pid)
    show(t)
    move(w, to: CGPoint(x: bounds.minX + 50, y: bounds.minY + 50))
    var ok = setFullScreen(w, true)
    if !ok { show(t); ok = setFullScreen(w, true) } // first try can hit a running animation
    guard ok else { return false }
    return waitUntil {
        guard let d = liveDisplays().first(where: { $0.uuid == display }) else { return false }
        return d.spaces.contains { $0.windowID == s.windowID && $0.id == d.current }
    }
}

@discardableResult
/// Target bars for the live Spaces (`targetLayout` on what SkyLight shows now).
func liveTarget(saved: Layout, titles: [CGWindowID: String]) -> Bars {
    let current = Dictionary(uniqueKeysWithValues: liveDisplays().map { d in
        (d.uuid, d.spaces.compactMap { s in
            s.isFullScreen
                ? bundleID(s.pid).map { LiveSpace(id: s.id, bundle: $0, window: s.windowID, title: s.windowID.flatMap { titles[$0] } ?? "") }
                : LiveSpace(id: s.id, bundle: desktopID)
        })
    })
    return targetLayout(current: current, saved: saved)
}

func restoreDrag() -> DragResult {
    guard AXIsProcessTrusted() else { print("Brak uprawnienia Dostępność."); return .failed }
    guard let saved = loadAll()[profileKey()] else { print("Brak zapisanego układu dla tych monitorów."); return .failed }
    if liveDisplays().contains(where: { $0.spaces.contains(where: \.isSplitView) }) {
        print("Na pasku jest Split View (dwa okna w jednej przestrzeni). Rozdziel go i spróbuj ponownie."); return .failed
    }
    let t0 = Date()
    let names = Dictionary(uniqueKeysWithValues: activeMonitors().map { ($0.uuid, String($0.uuid.prefix(4))) })
    let titles = liveTitles()
    func target() -> Bars { liveTarget(saved: saved, titles: titles) }
    if nextMove(cur: liveBars(), target: target()) == nil { print("Już ułożone"); return .done }
    let mouse = MouseHelper()   // starts now, comes up (≈1 s) while Spaces change displays
    aimNudge = [:]
    func home(_ id: Int) -> String? { liveBars().first { $0.value.contains(id) }?.key }

    // 1. Spaces on the wrong display, the slow way.
    let first = target(), cur = liveBars()
    for (d, ids) in first.sorted(by: { $0.key < $1.key }) {
        for id in ids where cur[d]?.contains(id) != true {
            let ok = moveToDisplay(id, d)
            print(String(format: "  %@ przestrzeń %d → monitor %@  (%.1f s)", ok ? "⇄" : "✗", id, names[d] ?? "?", Date().timeIntervalSince(t0)))
        }
    }

    // 2. Order inside each bar: one Mission Control session per display that needs it.
    guard let mouse, mouse.waitReady() else { return .noMouse }
    defer { mouse.quit() }
    let total = { liveDisplays().map(\.spaces.count).reduce(0, +) }
    for d in target().keys.sorted() {
        let want = target()[d]!
        guard nextMove(cur: liveBars()[d] ?? [], target: want) != nil else { continue }
        let r = inMissionControl(mouse, on: d) {
            let count = total()
            for _ in 0..<want.count {
                let bar = liveBars()[d] ?? []
                guard let move = nextMove(cur: bar, target: want) else { break }
                // Success = this Space right where it was meant to go, not just "the bar changed":
                // a press beside the thumbnail grabs a neighbour or hits a gap (T50). A miss tells
                // how far off the aim was (`aimError`); one corrected try, then the fallback.
                var moved = false
                for attempt in 0..<2 where !moved {
                    let before = liveBars()[d] ?? []
                    guard dragSpace(move.item, to: d, after: move.after, mouse: mouse) else { return .failed }
                    waitUntil(timeout: 1.5) { liveBars()[d] != before }
                    if total() != count { print("✗ przestrzenie się połączyły (Split View), przerywam"); return .failed }
                    let now = liveBars()[d] ?? []
                    moved = placed(move.item, after: move.after, in: now)
                    if !moved {
                        let err = aimError(before: before, after: now, intended: move.item)
                        print(String(format: "  ✗ chybione (próba %d): %@; %@, poprawka %+.1f miniatury", attempt + 1, lastAim,
                                     before == now ? "nic się nie ruszyło" : "ruszyło się co innego", err))
                        aimNudge[home(move.item) ?? d, default: 0] += err
                    }
                }
                let slot = (liveBars()[d]?.firstIndex(of: move.item) ?? -1) + 1
                print(String(format: "  %@ przestrzeń %d → monitor %@, miejsce %d  (%.1f s)", moved ? "↔" : "✗",
                             move.item, names[d] ?? "?", slot, Date().timeIntervalSince(t0)))
                if !moved { print("  nie trafiłem, przerywam"); return .failed }
            }
            return .done
        }
        if r != .done { return r }
    }
    let ok = nextMove(cur: liveBars(), target: target()) == nil
    print(String(format: ok ? "Gotowe w %.1f s" : "Nie wszystko ułożone (%.1f s)", Date().timeIntervalSince(t0)))
    return ok ? .done : .failed
}

/// Debug: `mcmove <Space ID> <display UUID prefix> [after ID] [y]`, one drag in a Mission Control
/// opened from the Space's display (e.g. to scramble for a test).
func mcmove(_ args: [String]) {
    guard args.count >= 2, let item = Int(args[0]),
          let d = activeMonitors().first(where: { $0.uuid.hasPrefix(args[1]) })?.uuid,
          let mouse = MouseHelper(), mouse.waitReady() else {
        print("Użycie: mcmove <ID przestrzeni> <początek UUID monitora> [po ID] [y]"); return
    }
    defer { mouse.quit() }
    debugBarY = args.count > 3 ? Double(args[3]).map { CGFloat($0) } : nil
    let home = liveBars().first { $0.value.contains(item) }?.key
    _ = inMissionControl(mouse, on: home) {
        let before = liveBars()
        _ = dragSpace(item, to: d, after: args.count > 2 ? Int(args[2]) : nil, mouse: mouse)
        print(waitUntil(timeout: 1.5) { liveBars() != before } ? "przesunięte" : "bez zmian")
        return .done
    }
}


// MARK: - P9: SkyLight WMBridge (macOS 26+), docs/experiments.md

/// Puts a Space at `index` (0-based final position, desktops included) on display `uuid`, also
/// moving it there from another display. Private `SLSBridgedMoveManagedSpaceToDisplayIndexOperation`,
/// works with SIP on from a process with AppKit loaded. Asynchronous: read the bar back to see it.
/// `fallback`: dispatch through `SLSWindowManagementFallbackBridge` (DesktopRenamer's route)
/// instead of `-performWithWMBridgeDelegate`.
func bridgedMoveSpace(_ space: Int, toDisplay uuid: String, index: Int, fallback: Bool = false) -> Bool {
    _ = NSApplication.shared   // AppKit must be loaded, or every perform is a no-op
    guard let cls = NSClassFromString("SLSBridgedMoveManagedSpaceToDisplayIndexOperation") as? NSObject.Type else { return false }
    let initSel = NSSelectorFromString("initWithSpaceID:displayIdentifier:index:")
    typealias Init = @convention(c) (AnyObject, Selector, UInt64, NSString, UInt32) -> AnyObject?
    guard let initImp = class_getMethodImplementation(cls, initSel),
          let raw = cls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
          let op = unsafeBitCast(initImp, to: Init.self)(raw, initSel, UInt64(space), uuid as NSString, UInt32(index)) else { return false }
    if fallback {
        guard let bridgeCls = NSClassFromString("SLSWindowManagementFallbackBridge") as? NSObject.Type else { return false }
        let bridge = bridgeCls.init()
        let sel = NSSelectorFromString("performAsynchronousBridgedWindowManagementOperation:")
        typealias Perform = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        guard let imp = class_getMethodImplementation(bridgeCls, sel) else { return false }
        unsafeBitCast(imp, to: Perform.self)(bridge, sel, op)
    } else {
        let sel = NSSelectorFromString("performWithWMBridgeDelegate")
        typealias Perform = @convention(c) (AnyObject, Selector) -> Void
        guard let imp = class_getMethodImplementation(object_getClass(op), sel) else { return false }
        unsafeBitCast(imp, to: Perform.self)(op, sel)
    }
    return true
}

/// Restore with the WMBridge move (P9): every Space set straight to its place and display, no
/// mouse, no Mission Control, no full screen. Displays one by one, positions left to right: once
/// places 0..<i are right, putting the target Space at i only pushes what belongs elsewhere
/// further right, and those are moved out when their own display comes. Desktops never change
/// display (`targetLayout`).
/// After a restart macOS reopens full-screen apps as ordinary windows, so the Spaces to move do
/// not exist yet. Saved full-screen entries without a live full-screen Space of that app get a
/// window of the app put into full screen (on the saved display), one by one: macOS switches
/// to each new Space and drops a request made meanwhile (T44). `restoreBridge` then places them.
func enterMissingFullScreen(_ saved: Layout) {
    let live = liveDisplays().flatMap(\.spaces).filter(\.isFullScreen)
    var have = Dictionary(grouping: live) { bundleID($0.pid) ?? "?" }.mapValues(\.count)
    var missing: [(entry: Entry, display: String)] = []
    for (d, entries) in saved.sorted(by: { $0.key < $1.key }) {
        for e in entries where !e.isDesktop {
            if have[e.bundleID, default: 0] > 0 { have[e.bundleID]! -= 1 } else { missing.append((e, d)) }
        }
    }
    guard !missing.isEmpty else { return }
    print("Nie na pełnym ekranie: \(missing.count) z zapisu (np. po restarcie), wstawiam je")
    slowRestoreStarts()
    let monitors = Dictionary(uniqueKeysWithValues: activeMonitors().map { ($0.uuid, $0.bounds) })
    var used = Set(live.compactMap(\.windowID))
    let t0 = Date()
    for (e, d) in missing {
        guard let t = normalWindow(e.bundleID, title: e.title, excluding: used), let id = t.id else {
            print("  ✗ \(e.app): brak okna (apka nie działa albo nie ma otwartego okna)"); continue
        }
        used.insert(id)
        let ok = enterFullScreen(t, on: monitors[d])
        print(String(format: "  %@ %@ %@  (%.1f s)", ok ? "⤢" : "✗", e.app, windowLabel(id), Date().timeIntervalSince(t0)))
    }
}

@discardableResult
func restoreBridge() -> Bool {
    guard let saved = loadAll()[profileKey()] else { print("Brak zapisanego układu dla tych monitorów."); return false }
    enterMissingFullScreen(saved)
    let t0 = Date(), target = liveTarget(saved: saved, titles: liveTitles())
    if liveBars().allSatisfy({ target[$0.key] == $0.value }) { print("Już ułożone"); return true }
    for (d, ids) in target.sorted(by: { $0.key < $1.key }) {
        for (i, id) in ids.enumerated() where liveBars()[d]?.firstIndex(of: id) != i {
            let ok = bridgedMoveSpace(id, toDisplay: d, index: i)
                && waitUntil(timeout: 2) { liveBars()[d]?.firstIndex(of: id) == i }
            print(String(format: "  %@ przestrzeń %d → monitor %@, miejsce %d  (%.2f s)", ok ? "⇢" : "✗", id, String(d.prefix(4)), i + 1, Date().timeIntervalSince(t0)))
        }
    }
    let ok = liveBars().allSatisfy { target[$0.key] == $0.value }
    print(String(format: "%@ w %.2f s", ok ? "Gotowe" : "Nie wszystko na miejscu", Date().timeIntervalSince(t0)))
    return ok
}

/// Debug: `spmove <spaceID> <display prefix | .> <index> [fb]`, bar before and after.
func spmoveCommand(_ args: [String]) {
    func bars() -> String {
        liveDisplays().map { d in "\(d.uuid.prefix(4)): " + d.spaces.map { s in
            "\(s.id)" + (s.isFullScreen ? "(\(bundleID(s.pid)?.split(separator: ".").last ?? "?"))" : "(biurko)") + (s.id == d.current ? "*" : "")
        }.joined(separator: " ") }.joined(separator: " | ")
    }
    guard args.count >= 3, let id = Int(args[0]), let index = Int(args[2]) else { print("spmove <spaceID> <monitor|.> <index> [fb]"); return }
    let displays = liveDisplays()
    let uuid = args[1] == "." ? displays.first { $0.spaces.contains { $0.id == id } }?.uuid : displays.first { $0.uuid.hasPrefix(args[1]) }?.uuid
    guard let uuid else { print("nie ma takiego monitora / przestrzeni"); return }
    print("przed: " + bars())
    let before = liveBars(), t0 = Date()
    print("wysłane: \(bridgedMoveSpace(id, toDisplay: uuid, index: index, fallback: args.dropFirst(3).first == "fb"))")
    let changed = waitUntil(timeout: 3) { liveBars() != before }
    print(String(format: "zmiana=%@ po %.0f ms", changed ? "tak" : "nie", Date().timeIntervalSince(t0) * 1000))
    Thread.sleep(forTimeInterval: 0.5)
    print("po:    " + bars())
}
