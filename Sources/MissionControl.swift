import AppKit
import ApplicationServices

// Experiment: reorder Spaces by dragging thumbnails in Mission Control's Spaces bar.
// macOS 27 notes (PaperWM.spoon #173 / PR #174):
// - the Mission Control AX tree lives in the WindowManager process, not the Dock;
// - a synthetic drag is ignored unless down/drag/up share one kCGMouseEventNumber and the
//   pointer actually moves in steps.

func openMissionControl() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = ["-a", "Mission Control"]
    try? p.run()
    p.waitUntilExit()
}

func closeMissionControl() {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: down)?.post(tap: .cghidEventTap) // Esc
    }
}

func missionControlRoots() -> [AXUIElement] {
    ["com.apple.WindowManager", "com.apple.dock"].flatMap { id in
        NSRunningApplication.runningApplications(withBundleIdentifier: id).map { AXUIElementCreateApplication($0.processIdentifier) }
    }
}

func children(_ el: AXUIElement) -> [AXUIElement] { attr(el, kAXChildrenAttribute) ?? [] }

func frame(_ el: AXUIElement) -> CGRect? {
    guard let p: AXValue = attr(el, kAXPositionAttribute), let s: AXValue = attr(el, kAXSizeAttribute) else { return nil }
    var origin = CGPoint.zero, size = CGSize.zero
    AXValueGetValue(p, .cgPoint, &origin)
    AXValueGetValue(s, .cgSize, &size)
    return CGRect(origin: origin, size: size)
}

func describeAX(_ el: AXUIElement) -> String {
    let role: String = attr(el, kAXRoleAttribute) ?? "?"
    let ident: String = attr(el, kAXIdentifierAttribute) ?? ""
    let t: String = attr(el, kAXTitleAttribute) ?? attr(el, kAXDescriptionAttribute) ?? ""
    let f = frame(el).map { "(\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height)))" } ?? ""
    return "\(role) id=\(ident) '\(t)' \(f)"
}

/// Debug: print the top of the Mission Control AX tree.
func mcdump() {
    openMissionControl()
    Thread.sleep(forTimeInterval: 1)
    func walk(_ el: AXUIElement, _ depth: Int) {
        print(String(repeating: "  ", count: depth) + describeAX(el))
        guard depth < 5 else { return }
        children(el).prefix(30).forEach { walk($0, depth + 1) }
    }
    missionControlRoots().forEach { walk($0, 0) }
    closeMissionControl()
}

func spacesList() -> AXUIElement? {
    func find(_ el: AXUIElement, _ depth: Int) -> AXUIElement? {
        if (attr(el, kAXIdentifierAttribute) as String?) == "mc.spaces.list" { return el }
        guard depth < 8 else { return nil }
        for c in children(el) { if let hit = find(c, depth + 1) { return hit } }
        return nil
    }
    return missionControlRoots().lazy.compactMap { find($0, 0) }.first
}

/// Every Spaces bar in Mission Control (one per display with "Displays have separate Spaces").
func spacesLists() -> [AXUIElement] {
    var out: [AXUIElement] = []
    func find(_ el: AXUIElement, _ depth: Int) {
        if (attr(el, kAXIdentifierAttribute) as String?) == "mc.spaces.list" { out.append(el); return }
        guard depth < 8 else { return }
        children(el).forEach { find($0, depth + 1) }
    }
    missionControlRoots().forEach { find($0, 0) }
    return out
}

/// Debug: every Spaces bar with its thumbnails, hovering over each display in turn
/// (a bar expands only under the cursor).
func mcbars() {
    // `mcbars <display prefix>`: Mission Control opened from that display, cursor over its bar,
    // AX thumbnail positions printed every 2 s for 12 s (time to take a screenshot to compare).
    guard let mouse = MouseHelper() else { return }
    defer { mouse.quit() }
    guard mouse.waitReady() else { return }
    let m = activeMonitors().first { $0.uuid.hasPrefix(CommandLine.arguments.dropFirst(2).first ?? "-") } ?? activeMonitors()[0]
    mouse.send("move \(m.bounds.midX) \(m.bounds.midY)")   // Mission Control takes input only on this display
    openMissionControl()
    guard waitUntil(timeout: 2, { !spacesLists().isEmpty }) else { print("Mission Control się nie otworzył"); return }
    mouse.send("move \(m.bounds.midX) \(m.bounds.minY + 20)")
    let t0 = Date()
    for wait in stride(from: 0.5, through: 12.5, by: 2.0) {
        Thread.sleep(forTimeInterval: max(0, wait - Date().timeIntervalSince(t0)))
        let bars = spacesLists().map { l -> String in
            let f = frame(l) ?? .zero
            let xs = children(l).compactMap(frame).map { "\(Int($0.minX))" }.joined(separator: ",")
            return "[x\(Int(f.minX)) y\(Int(f.minY)) h\(Int(f.height)): \(xs)]"
        }.joined(separator: " ")
        print(String(format: "+%.1fs ", wait) + bars)
    }
    openMissionControl()
}

/// Thumbnails of the Spaces bar (first display), left to right.
func spaceThumbnails() -> [AXUIElement] {
    guard let list = spacesList() else { return [] }
    return children(list).sorted { (frame($0)?.minX ?? 0) < (frame($1)?.minX ?? 0) }
}

// OpenJDK's Robot (and PaperWM) start above the real HID counters at 32000.
private var mouseEventNumber: Int64 = 32000 + Int64(Date().timeIntervalSince1970) % 10000

/// Hammerspoon (whose drags PaperWM uses on macOS 27) posts to the session tap with a nil
/// source and sleeps 1 ms after each post. `hid` in the arguments switches back for comparison.
let mouseTap: CGEventTapLocation = CommandLine.arguments.contains("hid") ? .cghidEventTap : .cgSessionEventTap

// macOS 27 checks synthetic input for an attached IOHIDEvent, the record real hardware
// events carry (Mac Mouse Fix f92d2d53a, MouseDragFix DockSwipe.swift do this for gestures).
// Experiment: attach a Pointer event with a child Button event to every mouse event.
// Enabled with `hidev` in the arguments.
private enum HID {
    typealias Create = @convention(c) (CFAllocator?, UInt32, UInt64, UInt32) -> Unmanaged<CFTypeRef>?
    typealias SetInt = @convention(c) (CFTypeRef, UInt32, Int) -> Void
    typealias SetDouble = @convention(c) (CFTypeRef, UInt32, Double) -> Void
    typealias Append = @convention(c) (CFTypeRef, CFTypeRef, UInt32) -> Void
    typealias Attach = @convention(c) (CGEvent, CFTypeRef) -> Void

    static func sym<T>(_ lib: String, _ name: String, _: T.Type) -> T? {
        guard let h = dlopen(lib, RTLD_LAZY), let p = dlsym(h, name) else { return nil }
        return unsafeBitCast(p, to: T.self)
    }
    static let iokit = "/System/Library/Frameworks/IOKit.framework/IOKit"
    static let create = sym(iokit, "IOHIDEventCreate", Create.self)
    static let setInt = sym(iokit, "IOHIDEventSetIntegerValue", SetInt.self)
    static let setDouble = sym(iokit, "IOHIDEventSetDoubleValue", SetDouble.self)
    static let append = sym(iokit, "IOHIDEventAppendEvent", Append.self)
    static let attach = sym("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", "SLEventSetIOHIDEvent", Attach.self)

    // IOHIDEventTypes.h: field = type << 16 | index
    static let pointer: UInt32 = 17, button: UInt32 = 2
    static func field(_ type: UInt32, _ i: UInt32) -> UInt32 { type << 16 | i }

    static func attachMouse(to e: CGEvent, pressed: Bool, dx: Double, dy: Double) {
        guard let create, let setInt, let setDouble, let append, let attach else { return }
        let ts = mach_absolute_time()
        guard let ev = create(nil, pointer, ts, 0)?.takeRetainedValue() else { return }
        setDouble(ev, field(pointer, 0), dx)                // PointerX (relative)
        setDouble(ev, field(pointer, 1), dy)                // PointerY
        setInt(ev, field(pointer, 3), pressed ? 1 : 0)      // PointerButtonMask
        if let b = create(nil, button, ts, 0)?.takeRetainedValue() {
            setInt(b, field(button, 0), pressed ? 1 : 0)    // ButtonMask
            setDouble(b, field(button, 1), pressed ? 1 : 0) // ButtonPressure
            setInt(b, field(button, 2), 1)                  // ButtonNumber
            setInt(b, field(button, 3), 1)                  // ButtonClickCount
            setInt(b, field(button, 4), pressed ? 1 : 0)    // ButtonState
            append(ev, b, 0)
        }
        attach(e, ev)
    }
}
let attachHID = CommandLine.arguments.contains("hidev")

/// One mouse event of a left-button gesture; all events of a gesture share `number`.
private func postMouse(_ type: CGEventType, _ p: CGPoint, number: Int64?, dx: Int64 = 0, dy: Int64 = 0) {
    guard let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left) else { return }
    e.flags = []
    if let number {
        e.setIntegerValueField(.mouseEventNumber, value: number)
        e.setIntegerValueField(.mouseEventClickState, value: 1)
        e.setIntegerValueField(.mouseEventDeltaX, value: dx)
        e.setIntegerValueField(.mouseEventDeltaY, value: dy)
        e.setDoubleValueField(.mouseEventPressure, value: type == .leftMouseUp ? 0 : 1) // real presses carry it
    }
    if attachHID {
        HID.attachMouse(to: e, pressed: type == .leftMouseDown || type == .leftMouseDragged, dx: Double(dx), dy: Double(dy))
    }
    e.post(tap: mouseTap)
    usleep(1000)
}

private func nextNumber() -> Int64 { mouseEventNumber += 1; return mouseEventNumber }

func click(at p: CGPoint) {
    let n = nextNumber()
    postMouse(.mouseMoved, p, number: nil); Thread.sleep(forTimeInterval: 0.05)
    postMouse(.leftMouseDown, p, number: n); Thread.sleep(forTimeInterval: 0.08)
    postMouse(.leftMouseUp, p, number: n)
}

/// Default mirrors PaperWM's macOS 27 drag (mission_control.lua `mouseDrag`): an 8 px nudge
/// right after mouse-down, then ~100 px steps 10 ms apart. `slow` imitates a hand instead:
/// a short hold, 10 px steps at ~60 Hz and a pause before release.
func drag(from: CGPoint, to: CGPoint, slow: Bool = false) {
    let n = nextNumber()
    let vx = to.x - from.x, vy = to.y - from.y
    let distance = (vx * vx + vy * vy).squareRoot()
    guard distance > 8 else { return }
    let stepLength: CGFloat = slow ? 10 : 100
    let pause = slow ? 0.016 : 0.01

    postMouse(.mouseMoved, from, number: nil); Thread.sleep(forTimeInterval: pause)
    postMouse(.leftMouseDown, from, number: n); Thread.sleep(forTimeInterval: slow ? 0.25 : pause)
    var previous = from
    func step(_ p: CGPoint) {
        postMouse(.leftMouseDragged, p, number: n, dx: Int64(p.x.rounded(.down) - previous.x.rounded(.down)),
                  dy: Int64(p.y.rounded(.down) - previous.y.rounded(.down)))
        previous = p
        Thread.sleep(forTimeInterval: pause)
    }
    let first = CGPoint(x: from.x + vx * 8 / distance, y: from.y + vy * 8 / distance)
    step(first)
    let steps = max(Int(((distance - 8) / stepLength).rounded(.up)), 1)
    for i in 1...steps {
        let k = CGFloat(i) / CGFloat(steps)
        step(CGPoint(x: first.x + (to.x - first.x) * k, y: first.y + (to.y - first.y) * k))
    }
    Thread.sleep(forTimeInterval: slow ? 0.3 : pause)
    postMouse(.leftMouseUp, to, number: n)
}

/// Test: drag Spaces-bar thumbnail `from` onto the slot of thumbnail `to` (1-based, like `list`).
/// The thumbnails' AX frames report a Y below where they are drawn, so the drag row comes from
/// the Spaces-bar list itself; `y` overrides it for calibration.
/// Test: a plain synthetic click on thumbnail `n` should switch to that Space and close Mission Control.
func mcclick(_ n: Int) {
    openMissionControl()
    guard waitUntil(timeout: 2, { !spaceThumbnails().isEmpty }) else { print("Brak paska"); closeMissionControl(); return }
    Thread.sleep(forTimeInterval: 0.3)
    postMouse(.mouseMoved, CGPoint(x: 756, y: 20), number: nil)
    Thread.sleep(forTimeInterval: 0.6)
    let thumbs = spaceThumbnails()
    guard thumbs.indices.contains(n - 1), let f = frame(thumbs[n - 1]), let bar = spacesList().flatMap(frame) else {
        print("Złe numery"); closeMissionControl(); return
    }
    print("Klikam \(n) w (\(Int(f.midX)), \(Int(bar.midY)))")
    click(at: CGPoint(x: f.midX, y: bar.midY))
    Thread.sleep(forTimeInterval: 1)
    if spacesList() != nil { print("Mission Control dalej otwarte, klik zignorowany"); closeMissionControl() }
}

func mcdrag(_ from: Int, _ to: Int, y: CGFloat? = nil, slow: Bool = false) {
    let t0 = Date()
    openMissionControl()
    guard waitUntil(timeout: 2, { !spaceThumbnails().isEmpty }) else {
        print("Nie widzę paska przestrzeni w Mission Control (sprawdź mcdump)"); closeMissionControl(); return
    }
    Thread.sleep(forTimeInterval: 0.3) // opening animation
    // The bar shows only names until the pointer is over it; hover so the thumbnails expand,
    // then read their frames (the collapsed frames overlap and are useless as drag targets).
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: 756, y: 20), mouseButton: .left)?
        .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.6)
    let thumbs = spaceThumbnails()
    print("Miniaturek: \(thumbs.count)")
    thumbs.enumerated().forEach { print("  \($0.offset + 1). \(describeAX($0.element))") }
    guard thumbs.indices.contains(from - 1), thumbs.indices.contains(to - 1),
          let a = frame(thumbs[from - 1]), let b = frame(thumbs[to - 1]) else {
        print("Złe numery albo brak ramek"); closeMissionControl(); return
    }
    let bar = spacesList().flatMap(frame)
    print("Pasek: \(bar.map { "\($0)" } ?? "?")")
    let row = y ?? bar?.midY ?? a.midY
    print("Przeciągam na wysokości y=\(Int(row))")
    drag(from: CGPoint(x: a.midX, y: row), to: CGPoint(x: b.midX, y: row), slow: slow)
    Thread.sleep(forTimeInterval: 0.4)
    closeMissionControl()
    Thread.sleep(forTimeInterval: 0.5)
    print(String(format: "Gotowe w %.1f s", Date().timeIntervalSince(t0)))
}

/// Debug: `axwin`, the running SpaceDock window's top AX elements with frames (to check the
/// layout without a screenshot).
func axwin() {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.wiciow.spacedock")
            .first(where: { $0.processIdentifier != getpid() }) else { print("SpaceDock nie działa"); return }
    func walk(_ el: AXUIElement, _ depth: Int) {
        print(String(repeating: "  ", count: depth) + describeAX(el))
        guard depth < 4 else { return }
        children(el).prefix(12).forEach { walk($0, depth + 1) }
    }
    for w in axWindows(pid: app.processIdentifier) {
        if let close: AXUIElement = attr(w, kAXCloseButtonAttribute) { print("zamknij: " + describeAX(close)) }
        walk(w, 0)
    }
}


/// Debug: `mcorder`, Space order as Mission Control shows it (thumbnail AX identifiers, left to
/// right per bar), to compare with SkyLight after a WMBridge move. No mouse needed.
func mcorder() {
    openMissionControl()
    guard waitUntil(timeout: 2, { !spacesLists().isEmpty }) else { print("Mission Control się nie otworzył"); return }
    Thread.sleep(forTimeInterval: 0.6)
    for l in spacesLists() {
        let items = children(l).sorted { (frame($0)?.minX ?? 0) < (frame($1)?.minX ?? 0) }
        print("MC: " + items.map { el -> String in
            let id: String = attr(el, kAXIdentifierAttribute) ?? "?"
            let name: String = attr(el, kAXTitleAttribute) ?? attr(el, kAXDescriptionAttribute) ?? ""
            return "\(id.split(separator: ".").last ?? "?")(\(name.prefix(12)))"
        }.joined(separator: " "))
    }
    openMissionControl()
}
