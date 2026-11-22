import AppKit

// Experiment P1f: record a real drag in Mission Control and replay it.
// If a replay of the exact recorded events works, synthetic drags can be built from
// recorded templates; if it doesn't, Mission Control filters on something we can't copy
// (e.g. the sender process). The field dumps show what real events carry that ours don't.

private let recordFile = store.deletingLastPathComponent().appendingPathComponent("recorded-drag.plist")

private typealias CopyHID = @convention(c) (CGEvent) -> Unmanaged<CFTypeRef>?
private let copyHID: CopyHID? = {
    guard let h = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
          let p = dlsym(h, "CGEventCopyIOHIDEvent") else { return nil }
    return unsafeBitCast(p, to: CopyHID.self)
}()

/// Every non-zero integer field 0...255, plus the attached IOHIDEvent, if any.
func dumpFields(_ e: CGEvent, _ label: String) {
    print("— \(label): type=\(e.type.rawValue) loc=(\(Int(e.location.x)),\(Int(e.location.y))) bytes=\(e.data.map { CFDataGetLength($0) } ?? 0)")
    var parts: [String] = []
    for raw in UInt32(0)...255 {
        guard let f = CGEventField(rawValue: raw) else { continue }
        let v = e.getIntegerValueField(f)
        if v != 0 { parts.append("\(raw)=\(v)") }
    }
    print("  pola: " + parts.joined(separator: " "))
    if let hid = copyHID?(e)?.takeRetainedValue() {
        print("  IOHIDEvent: " + (CFCopyDescription(hid) as String).replacingOccurrences(of: "\n", with: "\n    "))
    } else {
        print("  IOHIDEvent: brak")
    }
}

private var recorded: [(t: UInt64, data: Data)] = []
private var dumped = Set<UInt32>()

/// Records left-button events for `seconds`. Meanwhile: open Mission Control by hand and drag
/// one thumbnail in the Spaces bar.
func record(seconds: Double) {
    let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
    let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                      eventsOfInterest: mask, callback: { _, type, event, _ in
        if let d = event.data { recorded.append((event.timestamp, d as Data)) }
        if !dumped.contains(type.rawValue) { dumped.insert(type.rawValue); dumpFields(event, "prawdziwe") }
        return Unmanaged.passUnretained(event)
    }, userInfo: nil) else {
        print("Nie da się podsłuchać myszy (iTerm potrzebuje „Monitorowanie wejścia” w Prywatność i ochrona)"); return
    }
    let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    print("Nagrywam \(Int(seconds)) s: otwórz Mission Control i przeciągnij jedną miniaturkę na pasku…")
    CFRunLoopRunInMode(.defaultMode, seconds, false)
    CGEvent.tapEnable(tap: tap, enable: false)

    let plist = recorded.map { ["t": NSNumber(value: $0.t), "d": $0.data] as NSDictionary } as NSArray
    try? FileManager.default.createDirectory(at: recordFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    plist.write(to: recordFile, atomically: true)
    print("Zapisano \(recorded.count) zdarzeń do \(recordFile.path)")

    // Same dump for one of our synthetic presses, for side-by-side comparison.
    if let ours = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left) {
        dumpFields(ours, "nasze (sztuczne)")
    }
}

/// Opens Mission Control, hovers the bar, then posts the recorded events with their timing.
func replay() {
    guard let arr = NSArray(contentsOf: recordFile) as? [NSDictionary], !arr.isEmpty else {
        print("Brak nagrania, najpierw mcrecord"); return
    }
    openMissionControl()
    Thread.sleep(forTimeInterval: 1)
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: 756, y: 20), mouseButton: .left)?
        .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.6)
    var last: UInt64?
    for item in arr {
        guard let t = (item["t"] as? NSNumber)?.uint64Value, let d = item["d"] as? Data,
              let e = CGEvent(withDataAllocator: nil, data: d as CFData) else { continue }
        if let last, t > last { Thread.sleep(forTimeInterval: min(Double(t - last) / 1e9, 0.5)) }
        last = t
        e.post(tap: .cghidEventTap)
    }
    Thread.sleep(forTimeInterval: 0.5)
    if spacesList() != nil { closeMissionControl() }
    print("Odtworzono \(arr.count) zdarzeń")
}
