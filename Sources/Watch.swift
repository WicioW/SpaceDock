import AppKit

// `watch [--auto-save]`: stays running. After the monitor set changes (cable in/out),
// waits for macOS to finish reshuffling Spaces, then restores the saved order for the new set.
// `--auto-save` also saves order changes by itself (docs/experiments.md P7), with guards so it
// never saves the mess macOS makes right after a monitor change or during our own restore.

func log(_ s: String) {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    print("[\(f.string(from: Date()))] \(s)")
    fflush(stdout)
}

/// Bar order per display (apps and desktops), straight from SkyLight (no AX; cheap enough to
/// poll every second). Same shape as a saved layout's `Entry.key`s.
func liveAppOrder() -> [String: [String]] {
    Dictionary(uniqueKeysWithValues: liveDisplays().map { d in
        (d.uuid, d.spaces.compactMap { s in
            s.isFullScreen ? bundleID(s.pid).map { b in s.windowID.map { "\(b)#\($0)" } ?? b } : s.isSplitView ? nil : desktopID
        })
    })
}

/// Auto-save guard: quiet for 10 s after a monitor change or a restore, order unchanged for
/// 5 s, and different from what is saved.
func autoSaveDue(now: Date, lastDisplayChange: Date, lastRestore: Date, stableSince: Date,
                 current: [String: [String]], saved: [String: [String]]) -> Bool {
    now.timeIntervalSince(lastDisplayChange) > 10
        && now.timeIntervalSince(lastRestore) > 10
        && now.timeIntervalSince(stableSince) >= 5
        && current != saved
}

/// Set by every restore (watcher or the app's button) so auto-save never saves its middle steps.
// ponytail: plain globals touched from the app's background restore; a lock if it ever misfires.
var restoring = false
var lastRestoreAt = Date.distantPast
/// Called (off the main thread) right before a method that moves the mouse or windows: the app
/// shows its "do not touch" overlay then. The direct method needs none (no mouse, ~0.3 s).
var slowRestoreStarts: () -> Void = {}

/// The drag method needs Karabiner's virtual HID driver and the root helper (docs/app.md).
var dragAvailable: Bool {
    FileManager.default.fileExists(atPath: "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice")
        && FileManager.default.isExecutableFile(atPath: installedHelper)
}

/// restore-drag first (any number of monitors); the full-screen restore finishes the job when
/// the virtual mouse is unavailable or a drag did not take.
func runRestore() {
    restoring = true
    let key = profileKey()
    let shown = liveDisplays().map { d in (id: d.current, window: d.spaces.first { $0.id == d.current }?.windowID) }
    let front = NSWorkspace.shared.frontmostApplication
    defer {
        if profileKey() == key { returnTo(shown, front) }
        restoring = false; lastRestoreAt = Date()
    }
    // Method from the app's settings: "bridge" (default, P9: SkyLight WMBridge), "drag"
    // (Mission Control, Karabiner's virtual mouse) or "fullscreen" (P8, no Karabiner).
    switch UserDefaults.standard.string(forKey: "restoreMethod") ?? "bridge" {
    case "fullscreen": log("Metoda: pełny ekran"); slowRestoreStarts(); restore(fast: true); return
    case "bridge":
        log("Metoda: bezpośrednio (SkyLight)")
        if restoreBridge() { return }
        // A macOS update may drop the private operation: then drag, and full screen after that.
        guard profileKey() == key else { log("Monitory zmieniły się w trakcie układania, przerywam; ułożę po tej zmianie"); return }
        log("Bezpośrednio nie dokończyło, próbuję przeciąganiem")
    default: break
    }
    slowRestoreStarts()
    switch restoreDrag() {
    case .done: return
    // Monitors changed meanwhile (unplugged again, went to sleep): this layout no longer
    // applies, and the watcher sees the new set once `restoring` is off.
    case _ where profileKey() != key:
        log("Monitory zmieniły się w trakcie układania, przerywam; ułożę po tej zmianie"); return
    case .noMouse: log("Wirtualna mysz niedostępna, używam restore (pełny ekran)")
    case .failed: log("Przeciąganie nie dokończyło, używam restore (pełny ekran)")
    }
    restore()
}

/// Back to the Spaces that were shown before a restore (a re-entered full-screen window has a
/// new Space ID, so it is found by its window), the frontmost app's display last, then that app.
private func returnTo(_ shown: [(id: Int, window: CGWindowID?)], _ front: NSRunningApplication?) {
    let spaces = liveDisplays().flatMap(\.spaces)
    let back = shown.compactMap { s in spaces.first { $0.id == s.id } ?? spaces.first { s.window != nil && $0.windowID == s.window } }
    let frontPid = front?.processIdentifier
    for s in back.filter({ $0.pid != frontPid }) + back.filter({ $0.pid == frontPid }) { _ = goTo(s.id) }
    if let front, front.processIdentifier != getpid() { front.activate() }
}

/// Schedules the monitor watcher on the main run loop (CLI `watch` and the app). `autoSave` is
/// read on every tick, so the app's setting applies at once.
@discardableResult
func startWatch(autoSave: @escaping () -> Bool, autoRestore: @escaping () -> Bool = { true },
                restore: @escaping () -> Void = runRestore) -> Timer {
    // Monitor changes are detected by polling the display set: CGDisplayRegisterReconfigurationCallback
    // never fired in this CLI (test 2026-11-16, docs/experiments.md T32), while the polled list updates.
    var key = profileKey(), lastChange = Date.distantPast, pending = false
    var spaceIDs = liveDisplays().map { $0.spaces.map(\.id) }, idsStableSince = Date()
    var seen = liveAppOrder(), seenSince = Date()
    log("Pilnuję zmian monitorów. Zestaw: \(key). Zapis: \(autoSave() ? "automatyczny" : "ręczny")")

    return Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        guard !restoring else { return }
        let now = Date()
        let ids = liveDisplays().map { $0.spaces.map(\.id) }
        if ids != spaceIDs { spaceIDs = ids; idsStableSince = now }
        let k = profileKey()
        // No displays = asleep / screens off: not a monitor set, so nothing to restore; waking
        // up is then the change that counts.
        if k != key { key = k; lastChange = now; pending = !k.isEmpty }

        // Monitor change: wait 3 s after the last display change and 2 s of a still Spaces bar.
        if pending, now.timeIntervalSince(lastChange) > 3,
           now.timeIntervalSince(idsStableSince) > 2 {
            pending = false
            log("Zmiana monitorów → zestaw \(key), monitorów: \(activeMonitors().count)")
            if loadAll()[key] == nil { log("Brak zapisu dla tego zestawu, nic nie przestawiam") }
            else if autoRestore() { restore() }
            else { log("Przywracanie ręczne: kliknij Przywróć") }
            seen = liveAppOrder(); seenSince = Date()
        }

        guard autoSave(), !pending else { return }
        let current = liveAppOrder()
        if current != seen { seen = current; seenSince = now; return }
        let saved = (loadAll()[key] ?? [:]).mapValues { $0.map(\.key) }
        if autoSaveDue(now: now, lastDisplayChange: lastChange, lastRestore: lastRestoreAt,
                       stableSince: seenSince, current: current, saved: saved) {
            do {
                try storeLayout(currentLayout())
                log("Zapisano automatycznie: " + current.values.map { $0.map { $0.split(separator: "#")[0].split(separator: ".").last.map(String.init) ?? $0 }.joined(separator: " → ") }.joined(separator: " | "))
            } catch { log("Zapis się nie udał: \(error)") }
        }
    }
}

func watch(autoSave: Bool) {
    guard AXIsProcessTrusted() else { print("Brak uprawnienia Dostępność."); exit(1) }
    startWatch { autoSave }
    RunLoop.main.run()
}
