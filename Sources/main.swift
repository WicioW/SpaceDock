import AppKit
import ApplicationServices

// MARK: - Private, read-only SkyLight calls (no public API lists Spaces)

private let skylight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)

private func sym<T>(_ name: String, _: T.Type) -> T {
    guard let p = dlsym(skylight, name) else { fatalError("SkyLight symbol missing: \(name)") }
    return unsafeBitCast(p, to: T.self)
}

private let SLSMainConnectionID = sym("SLSMainConnectionID", (@convention(c) () -> Int32).self)
private let SLSCopyManagedDisplaySpaces = sym("SLSCopyManagedDisplaySpaces", (@convention(c) (Int32) -> Unmanaged<CFArray>).self)
private let SLSCopySpacesForWindows = sym("SLSCopySpacesForWindows", (@convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?).self)

/// Spaces a window is on (selector 7: all of them), e.g. the desktop holding an ordinary window.
func spaces(ofWindow id: CGWindowID) -> [Int] {
    let ids = [NSNumber(value: id)] as CFArray
    return (SLSCopySpacesForWindows(SLSMainConnectionID(), 7, ids)?.takeRetainedValue() as? [NSNumber])?.map(\.intValue) ?? []
}

/// AX element from a remote token (pid, 0, "coco", element ID): reaches windows on other Spaces,
/// which kAXWindowsAttribute leaves out. Same trick window switchers (AltTab) use.
@_silgen_name("_AXUIElementCreateWithRemoteToken")
private func _AXUIElementCreateWithRemoteToken(_ token: CFData) -> Unmanaged<AXUIElement>?

/// Process serial number of a pid, for SkyLight's front-process call (deprecated in the SDK,
/// so Swift hides it; still exported).
@_silgen_name("GetProcessForPID")
private func processForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

// MARK: - Model

struct Space {
    let id: Int
    let pid: pid_t?      // set only for full-screen Spaces
    let windowID: CGWindowID?
    var type = 0         // 0 = desktop, 4 = full screen (a Split View Space is 4 without one pid)
    var isFullScreen: Bool { pid != nil }
    var isSplitView: Bool { type == 4 && pid == nil }
}

struct Display {
    let uuid: String
    let spaces: [Space]
    let current: Int     // ManagedSpaceID shown on this display now
}

struct Entry: Codable, Equatable {
    let bundleID: String
    let app: String
    let title: String
    /// Window number of a full-screen Space: tells two windows of one app apart (two Brave
    /// windows). Kept across cable changes and full screen off/on, lost when the app quits.
    /// Saves from before it have none.
    var window: CGWindowID? = nil

    /// Compared with `liveAppOrder()`: app plus window, so swapping two windows of one app
    /// counts as a change.
    var key: String { window.map { "\(bundleID)#\($0)" } ?? bundleID }
}

/// Marks a desktop (not full-screen) Space in a saved layout, so its place in the bar is kept too.
let desktopID = "desktop"

extension Entry {
    var isDesktop: Bool { bundleID == desktopID }
}

/// display UUID -> Spaces in bar order: full-screen windows and desktops
typealias Layout = [String: [Entry]]

func liveDisplays() -> [Display] {
    let raw = SLSCopyManagedDisplaySpaces(SLSMainConnectionID()).takeRetainedValue() as? [[String: Any]] ?? []
    return raw.map { d in
        let spaces = (d["Spaces"] as? [[String: Any]] ?? []).map { s in
            Space(id: s["ManagedSpaceID"] as? Int ?? -1,
                  pid: (s["pid"] as? Int).map(pid_t.init),
                  windowID: (s["fs_wid"] as? Int).map(CGWindowID.init),
                  type: s["type"] as? Int ?? 0)
        }
        let current = (d["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int ?? -1
        return Display(uuid: d["Display Identifier"] as? String ?? "?", spaces: spaces, current: current)
    }
}

// MARK: - Monitors

func activeMonitors() -> [(uuid: String, bounds: CGRect)] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    CGGetActiveDisplayList(16, &ids, &count)
    return ids.prefix(Int(count)).compactMap { id in
        guard let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return (CFUUIDCreateString(nil, u) as String, CGDisplayBounds(id))
    }
}

/// Same set of monitors = same profile, regardless of which one is main.
func profileKey() -> String {
    activeMonitors().map(\.uuid).sorted().joined(separator: "+")
}

// MARK: - Accessibility

func attr<T>(_ el: AXUIElement, _ name: String) -> T? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v as? T : nil
}

/// Only windows on the currently shown Space(s) are listed.
func axWindows(pid: pid_t) -> [AXUIElement] {
    attr(AXUIElementCreateApplication(pid), kAXWindowsAttribute) ?? []
}

/// One window of the app by its number, also on a Space that is not shown (e.g. the title of a
/// full-screen Brave window behind another Space).
// ponytail: brute force over AX element IDs 0..<50000, ~10 µs each: ~0.5 s for a window not
// found. Chromium numbers every AX element from one counter, so a Brave window opened after long
// use sits past 2000 (6063, 2026-11-23); cache per pid if it ever runs out or feels slow.
func axWindow(pid: pid_t, id: CGWindowID) -> AXUIElement? {
    if let w = axWindows(pid: pid).first(where: { windowID($0) == id }) { return w }
    // Chromium and Electron apps (Brave, Claude, Bitwarden) give the window's number to inner
    // elements too (role AXUnknown, no title, ignore AXFullScreen), and those come first (T60).
    return remoteElements(pid: pid).first { windowID($0) == id && (attr($0, kAXRoleAttribute) as String?) == kAXWindowRole as String }
}

/// AX elements of an app reached through remote tokens (element IDs from `range`), lazily.
private func remoteElements(pid: pid_t, _ range: Range<UInt64> = 0..<50_000) -> AnySequence<AXUIElement> {
    var token = Data(count: 20)
    token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid) { Data($0) })
    token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
    token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f636f)) { Data($0) })
    return AnySequence(range.lazy.compactMap { element -> AXUIElement? in
        token.replaceSubrange(12..<20, with: withUnsafeBytes(of: element) { Data($0) })
        return _AXUIElementCreateWithRemoteToken(token as CFData)?.takeRetainedValue()
    })
}

/// Every standard window of an app: also on other Spaces, on desktops not shown, minimized.
/// kAXWindowsAttribute lists only windows of the shown Spaces (after a restart the windows are
/// spread over desktops and that list misses most of them).
func axAllWindows(pid: pid_t) -> [AXUIElement] {
    var out = axWindows(pid: pid), seen = Set(out.compactMap(windowID))
    for el in remoteElements(pid: pid) {
        guard let id = windowID(el), !seen.contains(id),
              (attr(el, kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole as String else { continue }
        out.append(el); seen.insert(id)
    }
    return out
}

/// An ordinary (not full-screen) window of the app, wherever it is, the one with `title` first.
/// Minimized windows come back, so they can go full screen.
func normalWindow(_ bundleID: String, title wanted: String = "", excluding: Set<CGWindowID>) -> Taken? {
    let all = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).flatMap { app in
        axAllWindows(pid: app.processIdentifier).map { (pid: app.processIdentifier, w: $0) }
    }.filter { c in windowID(c.w).map { !excluding.contains($0) } == true && !isFullScreen(c.w) }
    guard let c = all.first(where: { !wanted.isEmpty && title($0.w) == wanted }) ?? all.first else { return nil }
    if (attr(c.w, kAXMinimizedAttribute) as Bool?) == true {
        AXUIElementSetAttributeValue(c.w, kAXMinimizedAttribute as CFString, false as CFBoolean)
    }
    return Taken(bundleID: bundleID, title: title(c.w), window: c.w, id: windowID(c.w), pid: c.pid)
}

func windowID(_ w: AXUIElement) -> CGWindowID? {
    var id: CGWindowID = 0
    return _AXUIElementGetWindow(w, &id) == .success ? id : nil
}

func title(_ w: AXUIElement) -> String { attr(w, kAXTitleAttribute) ?? "" }

func isFullScreen(_ w: AXUIElement) -> Bool { attr(w, "AXFullScreen") ?? false }

func setFullScreen(_ w: AXUIElement, _ on: Bool, timeout: TimeInterval = 2) -> Bool {
    AXUIElementSetAttributeValue(w, "AXFullScreen" as CFString, on as CFBoolean)
    return waitUntil(timeout: timeout) { isFullScreen(w) == on }
}

func move(_ w: AXUIElement, to p: CGPoint) {
    var p = p
    if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, v) }
}

@discardableResult
func waitUntil(timeout: TimeInterval = 4, _ cond: () -> Bool) -> Bool {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end {
        if cond() { return true }
        Thread.sleep(forTimeInterval: 0.05)
    }
    return cond()
}

// MARK: - Space navigation

/// Presses Ctrl+←/→ ("Move left/right a space" in Keyboard Shortcuts, on by default).
/// The Space hotkey reacts only to a real-looking sequence: Control down, arrow (with the
/// fn/numpad flags a physical arrow key carries), Control up. A bare flagged arrow just
/// reaches the frontmost app as text.
func pressCtrlArrow(right: Bool) {
    let src = CGEventSource(stateID: .hidSystemState)
    let control: CGKeyCode = 59, arrow: CGKeyCode = right ? 124 : 123
    let steps: [(CGKeyCode, Bool, CGEventFlags)] = [
        (control, true, .maskControl),
        (arrow, true, [.maskControl, .maskSecondaryFn, .maskNumericPad]),
        (arrow, false, [.maskControl, .maskSecondaryFn, .maskNumericPad]),
        (control, false, []),
    ]
    for (key, down, flags) in steps {
        let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
        e?.flags = flags
        e?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)
    }
}

func isShown(_ spaceID: Int) -> Bool { liveDisplays().contains { $0.current == spaceID } }

/// Brings one window of an app to the front, by its number: macOS jumps to that window's Space,
/// also when the app has several full-screen windows (activating the app picks its last used
/// one). Private SkyLight, as window switchers do (AltTab): front process with that window, then
/// a key-window event record. False when a symbol is missing.
func focusWindow(pid: pid_t, id: CGWindowID) -> Bool {
    typealias Front = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    typealias Post = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    guard let f = dlsym(skylight, "_SLPSSetFrontProcessWithOptions"), let p = dlsym(skylight, "SLPSPostEventRecordTo") else { return false }
    var psn = ProcessSerialNumber()
    guard processForPID(pid, &psn) == noErr else { return false }
    _ = unsafeBitCast(f, to: Front.self)(&psn, id, 0x200)   // kCPSUserGenerated
    var bytes = [UInt8](repeating: 0, count: 0xF8)
    bytes[0x04] = 0xF8
    bytes[0x3A] = 0x10
    withUnsafeBytes(of: id) { bytes.replaceSubrange(0x3C..<0x40, with: $0) }
    for i in 0x20..<0x30 { bytes[i] = 0xFF }
    for kind: UInt8 in [1, 2] {   // key window: press, release
        bytes[0x08] = kind
        _ = unsafeBitCast(p, to: Post.self)(&psn, &bytes)
    }
    // The raise is what makes macOS switch to the window's Space; the two calls above alone
    // front the app but leave the screen where it is (JumpTest, 2026-11-23).
    if let w = axWindow(pid: pid, id: id) { AXUIElementPerformAction(w, kAXRaiseAction as CFString) }
    else { print("  AX okno \(windowLabel(id)): nie znalezione, skok nie przełączy przestrzeni") }
    return true
}

/// Shows `spaceID`. For a full-screen Space, focusing its window jumps there in one animation;
/// when that does not land there, steps with Ctrl+arrows.
/// Ctrl+arrows act on the display under the pointer, so the pointer is moved there first.
func goTo(_ spaceID: Int) -> Bool {
    if isShown(spaceID) { return true }
    let start = Date()
    let took = { String(format: "%.1f s", Date().timeIntervalSince(start)) }
    if let s = liveDisplays().flatMap(\.spaces).first(where: { $0.id == spaceID }), let pid = s.pid {
        let app = bundleID(pid) ?? "?"
        let how: String
        if let id = s.windowID, focusWindow(pid: pid, id: id) {
            how = "okno \(windowLabel(id))"
        } else {
            NSRunningApplication(processIdentifier: pid)?.activate()
            how = "aktywacja apki"
        }
        if waitUntil(timeout: 1.5, { isShown(spaceID) }) {
            print("  → przestrzeń \(spaceID) (\(app)): skok, \(how)  (\(took()))")
            Thread.sleep(forTimeInterval: 0.1)
            return true
        }
        let at = liveDisplays().map { String($0.current) }.joined(separator: ", ")
        print("  → przestrzeń \(spaceID) (\(app)): skok (\(how)) wylądował na \(at)")
    }
    var steps = 0
    for _ in 0..<30 {
        guard let d = liveDisplays().first(where: { $0.spaces.contains { $0.id == spaceID } }),
              let cur = d.spaces.firstIndex(where: { $0.id == d.current }),
              let dst = d.spaces.firstIndex(where: { $0.id == spaceID }) else { return false }
        if cur == dst {
            if steps > 0 { print("  → przestrzeń \(spaceID): strzałki ×\(steps)  (\(took()))") }
            Thread.sleep(forTimeInterval: 0.1) // let the slide animation finish before AX calls
            return true
        }
        if let b = activeMonitors().first(where: { $0.uuid == d.uuid })?.bounds,
           let at = CGEvent(source: nil)?.location, !b.contains(at) {
            CGWarpMouseCursorPosition(CGPoint(x: b.midX, y: b.midY))
        }
        pressCtrlArrow(right: dst > cur)
        steps += 1
        let moved = waitUntil(timeout: 2) { liveDisplays().first { $0.uuid == d.uuid }?.current != d.current }
        if !moved { print("Skrót Ctrl+strzałka nie przełączył przestrzeni"); return false }
    }
    return false
}

// MARK: - Commands

func describe(_ s: Space) -> Entry? {
    guard let pid = s.pid, let app = NSRunningApplication(processIdentifier: pid) else { return nil }
    let w = s.windowID.flatMap { axWindow(pid: pid, id: $0) }
    return Entry(bundleID: app.bundleIdentifier ?? "?", app: app.localizedName ?? "?", title: w.map(title) ?? "", window: s.windowID)
}

func list() {
    print("Accessibility:", AXIsProcessTrusted() ? "OK" : "BRAK")
    print("Profil:", profileKey())
    for d in liveDisplays() {
        print("\nMONITOR \(d.uuid)")
        for (i, s) in d.spaces.enumerated() {
            let mark = s.id == d.current ? " ← teraz" : ""
            guard s.isFullScreen else { print("  \(i + 1). [\(s.id)] Biurko\(mark)"); continue }
            let e = describe(s)
            print("  \(i + 1). [\(s.id)] \(e?.app ?? "?") — \(e?.title ?? "")\(mark)")
        }
    }
}

/// Moves a file or folder from its name before the 0.1 release (spaces-layout) to the new one,
/// once: only when the new one does not exist yet.
func movedFromOldName(_ old: String, _ new: String, in dir: String) -> URL {
    let base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(dir)
    let to = base.appendingPathComponent(new)
    if !FileManager.default.fileExists(atPath: to.path) { try? FileManager.default.moveItem(at: base.appendingPathComponent(old), to: to) }
    return to
}

let store = movedFromOldName("spaces-layout", "SpaceDock", in: "Library/Application Support").appendingPathComponent("layouts.json")

func loadAll() -> [String: Layout] {
    (try? JSONDecoder().decode([String: Layout].self, from: Data(contentsOf: store))) ?? [:]
}

/// Saves every Space per display in bar order: app, window title, window number (desktops as
/// `desktop`). Titles of windows on other Spaces come through `axWindow`.
func currentLayout() -> Layout {
    var layout = Layout()
    for d in liveDisplays() {
        layout[d.uuid] = d.spaces.compactMap { s in
            s.isFullScreen ? describe(s) : s.isSplitView ? nil : Entry(bundleID: desktopID, app: "Biurko", title: "")
        }
    }
    return layout
}

func storeLayout(_ layout: Layout) throws {
    var all = loadAll()
    all[profileKey()] = layout
    try writeAll(all)
}

func writeAll(_ all: [String: Layout]) throws {
    try FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true)
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try enc.encode(all).write(to: store)
}

func save() throws {
    let layout = currentLayout()
    try storeLayout(layout)
    print("Zapisano profil \(profileKey()) do \(store.path)")
    for (d, entries) in layout {
        print("  \(d):")
        entries.enumerated().forEach { print("    \($0.offset + 1). \($0.element.app) — \($0.element.title)") }
    }
}

/// Window number for the app log, which leaves titles out: they carry browser tabs, documents
/// and e-mail addresses, and people attach the log to bug reports.
func windowLabel(_ id: CGWindowID?) -> String { id.map { "#\($0)" } ?? "" }

struct Taken {
    let bundleID: String
    let title: String
    let window: AXUIElement
    let id: CGWindowID?
    let pid: pid_t
}

func goToDesktop() {
    if let desktop = liveDisplays().first?.spaces.first(where: { !$0.isFullScreen }) { _ = goTo(desktop.id) }
}

/// Brings the Space holding a (non-full-screen) window into view: raise + activate jumps
/// there in one animation; stepping to the desktop is the fallback.
/// Puts a window into full screen (on `bounds`' display), the new Space at the end of its bar.
/// First straight away, without showing the window's Space: that works for a window on a desktop
/// not shown, and the screen stays where it is (T56). Activating the app first, the old way, is
/// the fallback only: with another full-screen window of the same app (two Brave windows) macOS
/// jumps to that one instead and drops the request (T53).
func enterFullScreen(_ t: Taken, on bounds: CGRect?) -> Bool {
    let place = { if let b = bounds { move(t.window, to: CGPoint(x: b.minX + 50, y: b.minY + 50)) } }
    let onBar = { liveDisplays().flatMap(\.spaces).contains { $0.windowID == t.id } }
    place()
    if setFullScreen(t.window, true, timeout: 1.5) && waitUntil(timeout: 1.5, onBar) {
        Thread.sleep(forTimeInterval: 0.3)   // a request during macOS's own transition is dropped
        return true
    }
    // Some apps (Brave, IntelliJ) ignore it for a window on a desktop not shown (T58): show that
    // desktop. Its Space comes from SkyLight; activating the app is the last resort only.
    if let id = t.id, let space = spaces(ofWindow: id).first, goTo(space) {
        AXUIElementPerformAction(t.window, kAXRaiseAction as CFString)
        Thread.sleep(forTimeInterval: 0.2)
    } else {
        show(t)
    }
    place()
    guard setFullScreen(t.window, true), waitUntil(timeout: 3, onBar) else { return false }
    // Shown now: macOS switches to the new Space; the next window must not start meanwhile (T44).
    waitUntil { liveDisplays().contains { d in d.spaces.contains { $0.windowID == t.id && $0.id == d.current } } }
    return true
}

func show(_ t: Taken) {
    let visible = { axWindows(pid: t.pid).contains { windowID($0) == t.id } }
    if visible() { return }
    AXUIElementPerformAction(t.window, kAXRaiseAction as CFString)
    NSRunningApplication(processIdentifier: t.pid)?.activate()
    if waitUntil(timeout: 1.5, visible) { Thread.sleep(forTimeInterval: 0.1); return }
    goToDesktop()
}

func bundleID(_ pid: pid_t?) -> String? {
    pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
}


/// Greedy match of the saved order against the bar: returns how many saved entries can stay
/// and which current positions must be redone.
func keepPlan(current: [String], saved: [String]) -> (keep: Int, redo: [Int]) {
    var j = 0, redo: [Int] = []
    for (i, app) in current.enumerated() {
        if j < saved.count, app == saved[j] { j += 1 } else { redo.append(i) }
    }
    return (j, redo)
}

func selftest() {
    assert(keepPlan(current: ["A", "B", "C"], saved: ["A", "B", "C"]) == (3, []))
    assert(keepPlan(current: ["A", "X", "B", "C"], saved: ["A", "B", "C", "X"]) == (3, [1]))
    assert(keepPlan(current: ["B", "A"], saved: ["A", "B"]) == (1, [0]))
    assert(keepPlan(current: ["A"], saved: ["A", "B"]) == (1, []))  // B is on the desktop
    // restore-drag: saved apps in order (two of the same app), extras last; a Space already on
    // the display wins over the same app elsewhere
    func sp(_ id: Int, _ b: String, _ w: CGWindowID? = nil, _ t: String = "") -> LiveSpace { LiveSpace(id: id, bundle: b, window: w, title: t) }
    func en(_ b: String, _ w: CGWindowID? = nil, _ t: String = "") -> Entry { Entry(bundleID: b, app: b, title: t, window: w) }
    func tl(_ c: [String: [LiveSpace]], _ s: [String: [Entry]]) -> Bars { targetLayout(current: c, saved: s) }
    precondition(tl(["L": [sp(5, "X"), sp(2, "A"), sp(3, "B")], "M": [sp(4, "A")]],
                    ["L": [en("A"), en("B")], "M": [en("A"), en("X")]]) == ["L": [2, 3], "M": [4, 5]])
    // desktops: saved place kept; never taken from another display; unsaved ones go first
    let d = desktopID
    precondition(tl(["L": [sp(1, d), sp(2, "A"), sp(3, "B")]], ["L": [en("A"), en(d), en("B")]]) == ["L": [2, 1, 3]])
    precondition(tl(["L": [sp(2, "A"), sp(1, d)], "M": [sp(4, d), sp(3, "B")]],
                    ["L": [en("A"), en("B")], "M": [en(d), en(d)]]) == ["L": [1, 2, 3], "M": [4]])
    // two windows of one app: the window number decides, also across displays
    precondition(tl(["L": [sp(10, "A", 1), sp(11, "A", 2)]], ["L": [en("A", 2), en("A", 1)]]) == ["L": [11, 10]])
    precondition(tl(["L": [sp(10, "A", 1), sp(11, "A", 2)], "M": []],
                    ["L": [en("A", 2)], "M": [en("A", 1)]]) == ["L": [11], "M": [10]])
    // window reopened (new number): the title decides; the weak match of the first place must
    // not take the Space the second place's title needs
    precondition(tl(["L": [sp(10, "A", 7, "x"), sp(11, "A", 8, "y")]], ["L": [en("A", 1, "z"), en("A", 2, "x")]]) == ["L": [11, 10]])
    precondition(en("A", 5).key == "A#5" && en("A").key == "A")
    // window diff: saved order, gaps marked, unsaved Spaces where they stand now (after their
    // live neighbour, or first)
    let diff = layoutDiff(saved: ["L": [en(d), en("A"), en("B")]], live: ["L": [sp(4, "Y"), sp(1, d), sp(3, "X"), sp(2, "A")]]) { en($0.bundle) }
    precondition(diff["L"]!.map { "\($0.entry.bundleID):\($0.mark)" } == ["Y:unsaved", "\(d):none", "X:unsaved", "A:none", "B:missing"])
    // after a restart window numbers are reused: B's old number now on an A window must not win
    precondition(tl(["L": [sp(10, "A", 93), sp(11, "B", 7)]], ["L": [en("B", 93), en("A", 1)]]) == ["L": [11, 10]])
    // drag check: placed right after `after` (or first); aim error from what really moved
    precondition(placed(3, after: 1, in: [1, 3, 2]) && !placed(3, after: 1, in: [1, 2, 3]) && placed(3, after: nil, in: [3, 1]))
    precondition(aimError(before: [1, 2, 3, 4], after: [1, 2, 3, 4], intended: 2) == 0.5)   // gap: nothing moved
    precondition(aimError(before: [1, 2, 3, 4], after: [1, 2, 4, 3], intended: 2) == 1)     // grabbed 3 (right neighbour)
    precondition(aimError(before: [1, 2, 3, 4, 5], after: [1, 3, 4, 2, 5], intended: 3) == -1) // grabbed 2 (left neighbour)
    // nextMove across displays: applying its drags reaches the target
    func multiDrags(_ start: Bars, _ target: Bars) -> Int {
        var cur = start, n = 0
        while let m = nextMove(cur: cur, target: target) {
            for d in cur.keys { cur[d]!.removeAll { $0 == m.item } }
            let bar = cur[m.display]!
            cur[m.display]!.insert(m.item, at: m.after.flatMap { bar.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
            n += 1
            precondition(n <= 20, "nextMove does not converge")
        }
        precondition(cur == target)
        return n
    }
    precondition(multiDrags(["L": [1, 2, 3, 4], "M": [5, 6]], ["L": [1, 2, 3, 4], "M": [5, 6]]) == 0)
    precondition(multiDrags(["L": [1, 2, 3, 4, 6], "M": [5]], ["L": [1, 2, 3, 4], "M": [5, 6]]) == 1) // one Space on the wrong display
    precondition(multiDrags(["L": [6, 5, 1], "M": [2]], ["L": [1, 2], "M": [5, 6]]) == 3)
    // nextMove: applying its drags reaches the target in count - longest-in-order-run moves
    func drags(_ start: [Int], _ target: [Int]) -> Int {
        // single bar, as used inside each display
        var cur = start, n = 0
        while let m = nextMove(cur: cur, target: target) {
            cur.removeAll { $0 == m.item }
            cur.insert(m.item, at: m.after.flatMap { cur.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
            n += 1
            assert(n <= start.count, "nextMove does not converge")
        }
        assert(cur == target)
        return n
    }
    assert(drags([0, 6, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5, 6]) == 1)  // one Space jumped ahead
    assert(drags([0, 2, 3, 4, 5, 6, 1], [0, 1, 2, 3, 4, 5, 6]) == 1)  // first app ended up last
    assert(drags([0, 6, 5, 4, 3, 2, 1], [0, 1, 2, 3, 4, 5, 6]) == 5)  // fully reversed
    assert(drags([0, 1, 2], [0, 1, 2]) == 0)
    // watch --auto-save guard
    let t = Date(), old = t.addingTimeInterval(-60)
    let a = ["d": ["A", "B"]], b = ["d": ["B", "A"]]
    assert(autoSaveDue(now: t, lastDisplayChange: old, lastRestore: old, stableSince: old, current: b, saved: a))
    assert(!autoSaveDue(now: t, lastDisplayChange: t.addingTimeInterval(-3), lastRestore: old, stableSince: old, current: b, saved: a)) // monitor just changed
    assert(!autoSaveDue(now: t, lastDisplayChange: old, lastRestore: t.addingTimeInterval(-3), stableSince: old, current: b, saved: a)) // own restore
    assert(!autoSaveDue(now: t, lastDisplayChange: old, lastRestore: old, stableSince: t.addingTimeInterval(-2), current: b, saved: a)) // still moving
    assert(!autoSaveDue(now: t, lastDisplayChange: old, lastRestore: old, stableSince: old, current: a, saved: a))                    // nothing new
    // easter egg: the 10th quick click flies (and unlocks the panel look), not the 9th
    let egg = ShuttleEggState()
    var flights = 0
    for _ in 1...9 { egg.tap { flights += 1 } }
    assert(flights == 0)
    egg.tap { flights += 1 }
    assert(flights == 1 && egg.flightStart != nil)
    print("selftest OK")
}

/// `fast` (P8, T43): windows of other Spaces are reached through `axWindow`, so a window
/// leaves full screen without visiting its Space (no Ctrl+arrow scrolling), and the next window
/// goes full screen as soon as the previous Space is on the bar, not after macOS has shown it.
@discardableResult
func restore(fast: Bool = false) -> Bool {
    guard AXIsProcessTrusted() else { print("Brak uprawnienia Dostępność."); return false }
    guard let layout = loadAll()[profileKey()] else { print("Brak zapisanego układu dla tych monitorów."); return false }
    let monitors = Dictionary(uniqueKeysWithValues: activeMonitors().map { ($0.uuid, $0.bounds) })
    let t0 = Date()

    // 0. New Spaces can only be appended, so the Spaces that may stay are the longest start of
    // the saved order that already appears (in order) on the bar. Everything else is redone.
    var keep: [String: Int] = [:]
    var redo = Set<Int>()
    let liveWindows = Set(liveDisplays().flatMap(\.spaces).compactMap(\.windowID))
    for d in liveDisplays() {
        let fs = d.spaces.filter(\.isFullScreen)
        let saved = (layout[d.uuid] ?? []).filter { !$0.isDesktop }
        // Window number where the save has it and the window is still open, else just the app.
        let known = Set(saved.compactMap(\.window)).intersection(liveWindows)
        // App + window number: numbers are reused after a restart, by any app.
        let plan = keepPlan(current: fs.map { s in let b = bundleID(s.pid) ?? "?"; return s.windowID.flatMap { known.contains($0) ? "\(b)#\($0)" : nil } ?? b },
                            saved: saved.map { e in e.window.flatMap { known.contains($0) ? e.key : nil } ?? e.bundleID })
        keep[d.uuid] = plan.keep
        plan.redo.forEach { redo.insert(fs[$0].id) }
    }
    let missing = layout.reduce(0) { $0 + $1.value.filter { !$0.isDesktop }.count - (keep[$1.key] ?? 0) }
    if redo.isEmpty && missing == 0 { print("Już ułożone"); return true }
    print("Zostaje \(keep.values.reduce(0, +)), do przestawienia \(missing)")

    // 1. Take the out-of-place windows out of full screen. They land on the desktop.
    // A Space that can't be handled is skipped (left as is), never a reason to stop halfway:
    // stopping here would leave windows stranded off full screen.
    var taken: [Taken] = []
    var skipped = Set<Int>()
    while let s = liveDisplays().flatMap(\.spaces).first(where: { redo.contains($0.id) && !skipped.contains($0.id) }) {
        let found: AXUIElement? = fast
            ? s.pid.flatMap { pid in s.windowID.flatMap { axWindow(pid: pid, id: $0) } }
            : goTo(s.id) ? s.pid.flatMap { pid in axWindows(pid: pid).first { windowID($0) == s.windowID } } : nil
        guard let pid = s.pid, let w = found else {
            print("  ? pomijam przestrzeń \(s.id)"); skipped.insert(s.id); continue
        }
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "?"
        guard setFullScreen(w, false) else {
            print("  ? \(bundleID) nie wyszło z pełnego ekranu, pomijam"); skipped.insert(s.id); continue
        }
        taken.append(Taken(bundleID: bundleID, title: title(w), window: w, id: windowID(w), pid: pid))
        // AX flips the flag before the Space is gone; wait for the bar to settle.
        waitUntil { !liveDisplays().flatMap(\.spaces).contains { $0.id == s.id } }
        Thread.sleep(forTimeInterval: 0.05)
        print(String(format: "  ↓ %@ %@  (%.1f s)", bundleID, windowLabel(windowID(w)), Date().timeIntervalSince(t0)))
    }

    // 2. Full-screen them again in saved order; each new Space goes to the end of the bar.
    func fullScreen(_ t: Taken, on bounds: CGRect?) {
        let ok = enterFullScreen(t, on: bounds)
        print(String(format: "  %@ %@ %@  (%.1f s)", ok ? "↑" : "✗", t.bundleID, windowLabel(t.id), Date().timeIntervalSince(t0)))
    }
    for (display, entries) in layout.sorted(by: { $0.key < $1.key }) {
        let bounds = monitors[display]
        if bounds == nil { print("Monitor \(display) niepodłączony, jego okna idą na bieżący ekran") }
        for e in entries.filter({ !$0.isDesktop }).dropFirst(keep[display] ?? 0) {
            let i = taken.firstIndex { e.window != nil && $0.id == e.window && $0.bundleID == e.bundleID }
                ?? taken.firstIndex { $0.bundleID == e.bundleID && $0.title == e.title }
                ?? taken.firstIndex { $0.bundleID == e.bundleID }
            let t = i.map { taken.remove(at: $0) }
                ?? normalWindow(e.bundleID, title: e.title, excluding: Set(taken.compactMap(\.id)))
            guard let t else { print("  ✗ \(e.app) \(windowLabel(e.window)): brak takiego okna"); continue }
            fullScreen(t, on: bounds)
        }
    }
    // 3. Full-screen windows that were not in the saved layout go back at the end.
    taken.forEach { fullScreen($0, on: nil) }
    print(String(format: "Gotowe w %.1f s", Date().timeIntervalSince(t0)))
    return true
}

// MARK: - Main

signal(SIGPIPE, SIG_IGN)   // a dead helper's pipe must fail a write, not kill the app

// Launched from the .app bundle (tools/make-app.sh) without arguments = the window app.
switch CommandLine.arguments.dropFirst().first ?? (Bundle.main.bundlePath.hasSuffix(".app") ? "app" : nil) {
case "app": runApp()
case "list": list()
case "spmove": spmoveCommand(Array(CommandLine.arguments.dropFirst(2)))
case "fstest":   // T43: full screen off and on again for one window, without visiting its Space
    let t0 = Date(), arg = CommandLine.arguments.dropFirst(2).first ?? "Fork"
    func shown() -> [Int] { liveDisplays().map(\.current) }
    func at(_ msg: String) { print(String(format: "%5.2f s  %@  pokazane=%@", Date().timeIntervalSince(t0), msg, "\(shown())")) }
    guard let s = liveDisplays().flatMap(\.spaces).first(where: { $0.isFullScreen && (String($0.id) == arg || (bundleID($0.pid) ?? "").localizedCaseInsensitiveContains(arg)) }),
          let pid = s.pid, let id = s.windowID, let w = axWindow(pid: pid, id: id) else { print("nie ma takiej przestrzeni: \(arg)"); exit(1) }
    at("start: przestrzeń \(s.id) \(bundleID(pid) ?? "?"), widoczne=\(axWindows(pid: pid).contains { windowID($0) == id })")
    AXUIElementSetAttributeValue(w, "AXFullScreen" as CFString, false as CFBoolean)
    at("ustawione off")
    let gone = waitUntil(timeout: 5) { !liveDisplays().flatMap(\.spaces).contains { $0.id == s.id } }
    at("przestrzeń zniknęła=\(gone), AXFullScreen=\(isFullScreen(w))")
    Thread.sleep(forTimeInterval: 0.3)
    AXUIElementSetAttributeValue(w, "AXFullScreen" as CFString, true as CFBoolean)
    at("ustawione on")
    let back = waitUntil(timeout: 5) { liveDisplays().flatMap(\.spaces).contains { $0.windowID == id } }
    at("nowa przestrzeń=\(back), AXFullScreen=\(isFullScreen(w))")
    Thread.sleep(forTimeInterval: 1)
    at("po 1 s")
case "fson":   // T56: full screen on for a window by number, without showing its Space first
    let id = CGWindowID(CommandLine.arguments.dropFirst(2).first ?? "") ?? 0, t0 = Date()
    guard let app = NSWorkspace.shared.runningApplications.first(where: { axWindow(pid: $0.processIdentifier, id: id) != nil }),
          let w = axWindow(pid: app.processIdentifier, id: id) else { print("nie ma okna #\(id)"); exit(1) }
    print("pokazane przed: \(liveDisplays().map(\.current))")
    let on = CommandLine.arguments.dropFirst(3).first != "off"   // `fson <id> off`: leave full screen
    AXUIElementSetAttributeValue(w, "AXFullScreen" as CFString, on as CFBoolean)
    let ok = waitUntil(timeout: 4) { liveDisplays().flatMap(\.spaces).contains { $0.windowID == id } == on }
    print(String(format: "nowa przestrzeń=%@ po %.2f s, pokazane po: %@", ok ? "tak" : "nie", Date().timeIntervalSince(t0), "\(liveDisplays().map(\.current))"))
case "axwhich":   // debug: role and title of what axWindow returns for every full-screen Space
    for s in liveDisplays().flatMap(\.spaces) where s.isFullScreen {
        guard let pid = s.pid, let id = s.windowID, let w = axWindow(pid: pid, id: id) else { continue }
        print("[\(s.id)] \(bundleID(pid) ?? "?") #\(id): rola=\((attr(w, kAXRoleAttribute) as String?) ?? "?") podrola=\((attr(w, kAXSubroleAttribute) as String?) ?? "?") „\(title(w).prefix(30))”")
    }
case "allwin":   // debug: every window of an app the restore can find (`allwin com.brave.Browser`)
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments.dropFirst(2).first ?? "") {
        for w in axAllWindows(pid: app.processIdentifier) {
            var settable: DarwinBoolean = false
            AXUIElementIsAttributeSettable(w, "AXFullScreen" as CFString, &settable)
            var size = CGSize.zero
            if let v: AXValue = attr(w, kAXSizeAttribute) { AXValueGetValue(v, .cgSize, &size) }
            print("#\(windowID(w) ?? 0) „\(title(w).prefix(40))” pełny=\(isFullScreen(w)) ustawialny=\(settable.boolValue) min=\((attr(w, kAXMinimizedAttribute) as Bool?) ?? false) \(Int(size.width))×\(Int(size.height)) przycisk=\((attr(w, kAXFullScreenButtonAttribute) as AXUIElement?) != nil)")
        }
    }
case "fsprobe":   // read-only: can full screen be toggled on windows of Spaces not shown?
    for s in liveDisplays().flatMap(\.spaces) where s.isFullScreen {
        guard let pid = s.pid, let id = s.windowID, let w = axWindow(pid: pid, id: id) else { print("[\(s.id)] brak elementu AX"); continue }
        var settable: DarwinBoolean = false
        let err = AXUIElementIsAttributeSettable(w, "AXFullScreen" as CFString, &settable)
        let shown = axWindows(pid: pid).contains { windowID($0) == id }
        print("[\(s.id)] \(bundleID(pid) ?? "?") widoczne=\(shown) AXFullScreen=\(isFullScreen(w)) ustawialne=\(settable.boolValue) (\(err.rawValue))")
    }
case "save": try save()
case "restore": withOverlay { restore() }; list()
case "restore-fast": withOverlay { restore(fast: true) }; list()
case "restore-bridge": withOverlay { restoreBridge() }; list()
case "goto": print(goTo(Int(CommandLine.arguments.last ?? "") ?? -1) ? "OK" : "Nie udało się")
case "panel-shot": panelShot(Array(CommandLine.arguments.dropFirst(2)))
case "dmg-background": MainActor.assumeIsolated { dmgBackground(Array(CommandLine.arguments.dropFirst(2))) }
case "selftest": selftest()
case "mcdump": mcdump()
case "mcbars": mcbars()
case "mcorder": mcorder()
case "axwin": axwin()
case "mcmove": mcmove(Array(CommandLine.arguments.dropFirst(2))); list()
case "mcdrag":
    let a = CommandLine.arguments.dropFirst(2).compactMap { Int($0) }
    guard a.count >= 2 else { print("Użycie: mcdrag <z> <na> [y] [slow]"); exit(1) }
    mcdrag(a[0], a[1], y: a.count > 2 ? CGFloat(a[2]) : nil, slow: CommandLine.arguments.contains("slow")); list()
case "watch":
    watch(autoSave: CommandLine.arguments.contains("--auto-save"))
case "vhid-serve":
    vhidServe()
case "restore-drag":
    withOverlay { restoreDrag() }; list()
case "vhid-click", "vhid-drag":
    vhidCommand(Array(CommandLine.arguments.dropFirst()))
case "mcclickv":
    mcclickV(CommandLine.arguments.dropFirst(2).compactMap { Int($0) }.first ?? -1); list()
case "mcdragv":
    let a = CommandLine.arguments.dropFirst(2).compactMap { Int($0) }
    guard a.count == 2 else { print("Użycie: mcdragv <z> <na>"); exit(1) }
    mcdragV(a[0], a[1]); list()
case "mcrecord":
    record(seconds: Double(CommandLine.arguments.dropFirst(2).compactMap { Int($0) }.first ?? 10)); list()
case "mcreplay":
    replay(); list()
case "mcclick":
    mcclick(CommandLine.arguments.dropFirst(2).compactMap { Int($0) }.first ?? -1); list()
default: print("Użycie: spaces-layout app | list | save | restore | goto <ID> | mcdump | mcdrag <z> <na>")
}
