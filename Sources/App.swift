import SwiftUI
import AppKit
import ServiceManagement

// `spaces-layout app` (or the .app bundle): window with the saved Spaces per monitor set,
// plus a menu bar icon. Reading and saving need no Accessibility; restore and the watcher do.

let logFile = movedFromOldName("spaces-layout.log", "SpaceDock.log", in: "Library/Logs")
let supportURL = URL(string: "https://ko-fi.com/wiciow")!   // menu bar, Settings (both looks), README

private let languages = ["pl", "en", "es", "zh-Hans"]

/// The app's own language, "" = the system's. Same per-app AppleLanguages override that macOS
/// writes from Language & Region → Applications, so both places stay in sync.
func appLanguage() -> String {
    guard let first = (UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String])?.first
    else { return "" }
    return languages.first { first.hasPrefix($0) } ?? ""
}

/// Language is read once at launch, so a change restarts the app: a shell waits for this
/// process to exit, then opens the bundle again.
func setAppLanguage(_ lang: String) {
    guard lang != appLanguage() else { return }
    if lang.isEmpty { UserDefaults.standard.removeObject(forKey: "AppleLanguages") } else { UserDefaults.standard.set([lang], forKey: "AppleLanguages") }
    guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-c", "while kill -0 $1 2>/dev/null; do sleep 0.2; done; open \"$0\"", Bundle.main.bundlePath, "\(getpid())"]
    try? p.run()
    NSApp.terminate(nil)
}

/// Bundle ID before the public release; its settings (method, modes, language) move over once.
private let oldBundleID = "local.spaces-layout"

func runApp() {
    if let id = Bundle.main.bundleIdentifier, id != oldBundleID,
       UserDefaults.standard.persistentDomain(forName: id)?.isEmpty ?? true,
       let old = UserDefaults.standard.persistentDomain(forName: oldBundleID), !old.isEmpty {
        UserDefaults.standard.setPersistentDomain(old, forName: id)
    }
    freopen(logFile.path, "a", stdout)   // every print (watcher, restore steps) goes to the log
    setvbuf(stdout, nil, _IOLBF, 0)      // line by line, not when the buffer fills
    SpacesApp.main()
}

struct ScreenInfo: Codable, Equatable {
    var name: String
    var x: Double
    var builtin: Bool
}

/// Names and positions of monitors seen so far, so a disconnected monitor still has a name.
private let screensFile = store.deletingLastPathComponent().appendingPathComponent("screens.json")

struct DeleteRequest: Identifiable {
    let id = UUID()
    let key: String
    let layout: String
}

struct Naming: Identifiable {
    let id = UUID()
    let first: Bool   // the set has no layout yet
}

final class Model: ObservableObject {
    @Published var saved: [String: Layout] = [:]   // selected layout of each set
    @Published var sets: [String: LayoutSet] = [:]
    @Published var viewedID: String? {   // layout clicked in the sidebar for `selection`; nil = its selected one
        didSet {
            if renaming != nil, renaming != viewedID { commitRenaming() }   // clicking elsewhere saves a rename
            if viewedID != oldValue { clearKeyboard() }   // another layout: the monitor frame belongs to the old one
        }
    }
    @Published var expanded: Set<String> = []   // sets opened in the sidebar tree
    @Published var naming: Naming?   // "save as new" / first save sheet
    @Published var newName = ""
    @Published var renaming: String?   // layout being renamed in its sidebar row
    @Published var rowMenu: String?    // layout whose ⋯ actions are open under its rail row (neon)
    @Published var drafts: [String: String] = [:]   // text typed into a layout's name field
    @Published var deleting: DeleteRequest?   // the neon look's own "delete layout?" sheet
    @Published var panelSettingsOpen = UserDefaults.standard.bool(forKey: "shotSettings")   // the neon look's settings window (design RU); `-shotSettings YES` for panel-shot
    @Published var current = ""
    @Published var live: [String: [String]] = [:]
    @Published var liveSpaces: [String: [LiveSpace]] = [:]   // bars now, for the saved-vs-live tiles
    @Published var screens = (try? JSONDecoder().decode([String: ScreenInfo].self, from: Data(contentsOf: screensFile))) ?? [:]
    @Published var selection: String? { didSet { if selection != oldValue { clearKeyboard() } } }
    @Published var busy = false
    @Published var pickedSpace: Int?   // tile clicked once in the window (white ring); twice = go there
    @Published var columns = NavigationSplitViewVisibility.all   // sidebar shown or hidden (@State needs a macro plugin the CLI toolchain lacks)
    @Published var trusted = AXIsProcessTrusted()
    @Published var loginItem = SMAppService.mainApp.status == .enabled
    private var timer: Timer?
    private var watcher: Timer?
    private var arrows: Any?

    init() {
        refresh()
        selection = current
        expanded = [current]
        timer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        // Global shortcuts: save asks before replacing a save (as the button does); restore beeps
        // when there is nothing to restore.
        let restore = { [weak self] (openApps: Bool) in
            guard let self, self.saved[self.current] != nil, self.trusted, !self.busy else { NSSound.beep(); return }
            self.restoreNow(openApps: openApps)
        }
        Hotkeys.shared.start([.save: { [weak self] in
                                  guard let self, self.saved[self.current] != nil else { NSSound.beep(); return }   // naming needs the window
                                  self.save() },
                              .restore: { restore(false) }, .restoreOpen: { restore(true) }],
                             layouts: { [weak self] in self?.restorePosition($0) })
        // Keys while the window is on top (both looks), two levels:
        // ↑ / ↓ the previous / next layout of any set (preview only), ← / → a monitor of it (framed);
        // Enter goes into the framed monitor's Spaces, ← / → walk them, Enter shows that Space
        // (layout on screen only), Esc goes back a level. Not while typing a name or with a sheet open.
        arrows = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, e.window?.identifier?.rawValue.contains("main") == true,
                  e.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  !(e.window?.firstResponder is NSText),
                  self.naming == nil, self.renaming == nil, self.deleting == nil, !self.panelSettingsOpen,
                  self.key(e.keyCode) else { return e }
            return nil   // handled: the sidebar list would otherwise also move its row or fold the set
        }
    }

    // MARK: Keyboard in the window (docs/app.md, "Klawiatura w oknie")

    @Published var kbMonitor: String?   // monitor framed by ← / →
    @Published var kbTile: Int?         // its Space picked after Enter (index in the monitor's tiles)
    @Published var kbNote: String?      // why Enter did not go there: a red ring and this under the tile

    func clearKeyboard() { kbMonitor = nil; kbTile = nil; kbNote = nil }

    /// The tiles of the framed monitor as the window shows them.
    private func kbTiles() -> [PanelTile] {
        let key = selection ?? current
        return PanelData(self, key: key, layout: viewed(key)?.layout).monitors.first { $0.uuid == kbMonitor }?.tiles ?? []
    }

    /// One key; false = not ours (the window gets it).
    private func key(_ code: UInt16) -> Bool {
        let key = selection ?? current
        switch code {
        case 126, 125:   // ↑ ↓
            if kbTile == nil { stepLayout(code == 125 ? 1 : -1) }
        case 123, 124:   // ← →
            let d = code == 124 ? 1 : -1
            if let t = kbTile {
                if kbTiles().indices.contains(t + d) { kbTile = t + d; kbNote = nil }
            } else {
                let ms = displays(key)
                guard !ms.isEmpty else { return true }
                if let m = kbMonitor, let i = ms.firstIndex(of: m) {
                    if ms.indices.contains(i + d) { kbMonitor = ms[i + d] }
                } else {
                    kbMonitor = d > 0 ? ms.first : ms.last
                }
            }
        case 36, 76:   // Return, Enter
            if let t = kbTile {
                let ts = kbTiles()
                guard ts.indices.contains(t) else { kbTile = nil; return true }
                if key != current { kbNote = "Ten zestaw monitorów nie jest podłączony" }
                else if isPreview(key) { kbNote = "Ten układ nie jest na ekranie" }
                else if let id = ts[t].space { kbNote = nil; pickedSpace = id; DispatchQueue.global().async { _ = goTo(id) } }
                else { kbNote = ts[t].entry.isDesktop ? "Brak biurka" : "Nie otwarte" }
            } else if kbMonitor != nil {
                if kbTiles().isEmpty { NSSound.beep() } else { kbTile = 0 }
            } else { return false }
        case 53:   // Esc
            if kbTile != nil { kbTile = nil; kbNote = nil }
            else if kbMonitor != nil { kbMonitor = nil }
            else { return false }
        default: return false
        }
        return true
    }

    /// ↑ / ↓: the previous / next layout in the sidebar, across sets (sets without one are skipped).
    /// Stops at the ends.
    func stepLayout(_ d: Int) {
        let ps = profiles
        let all = ps.flatMap { k in layouts(k).map { (k, $0.id) } }
        let key = selection ?? current, at = ps.firstIndex(of: key) ?? 0
        let next: (String, String)?
        if let id = viewed(key)?.id, let i = all.firstIndex(where: { $0 == (key, id) }) {
            next = all.indices.contains(i + d) ? all[i + d] : nil
        } else {   // a set with no layout: the nearest one after / before it
            next = d > 0 ? all.first { (ps.firstIndex(of: $0.0) ?? 0) > at } : all.last { (ps.firstIndex(of: $0.0) ?? 0) < at }
        }
        guard let (k, id) = next else { return }
        selection = k
        viewedID = id
        expanded.insert(k)
        clearKeyboard()
    }

    func refresh() {
        let t = AXIsProcessTrusted()
        if t != trusted { trusted = t }
        if t, watcher == nil {
            watcher = startWatch(autoSave: { UserDefaults.standard.bool(forKey: "autoSave") },
                                 autoRestore: { UserDefaults.standard.object(forKey: "autoRestore") as? Bool ?? true },
                                 restore: { [weak self] in self?.restoreNow(openApps: false) })
        }
        let all = loadSets(), key = profileKey(), order = liveAppOrder()
        if all != sets { sets = all }
        let selected = all.compactMapValues { $0.current?.layout }
        if selected != saved { saved = selected }
        if key != current { current = key; expanded.insert(key) }
        if order != live { live = order }
        // ponytail: no AX titles here (polled every 2 s), so the diff matches by window and app
        // only; a restore also uses titles, which matters only for two windows of one app after a restart.
        let spaces = Dictionary(uniqueKeysWithValues: liveDisplays().map { d in
            (d.uuid, d.spaces.compactMap { s -> LiveSpace? in
                s.isFullScreen ? bundleID(s.pid).map { LiveSpace(id: s.id, bundle: $0, window: s.windowID) }
                    : s.isSplitView ? nil : LiveSpace(id: s.id, bundle: desktopID)
            })
        })
        if spaces != liveSpaces { liveSpaces = spaces }
        var s = screens
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { continue }
            s[CFUUIDCreateString(nil, u) as String] =
                ScreenInfo(name: screen.localizedName, x: screen.frame.minX, builtin: CGDisplayIsBuiltin(id) != 0)
        }
        if s != screens { screens = s; try? JSONEncoder().encode(s).write(to: screensFile) }
    }

    /// panel-shot `-shotDemo <file>`: made-up monitors and the connected set instead of this Mac's
    /// (README pictures without real window titles). The bars are the set's selected layout, so
    /// the screen matches the save; saves come from `-setsFile`.
    func demo(_ file: String) {
        struct Demo: Decodable { let current: String; let screens: [String: ScreenInfo] }
        guard let d = try? JSONDecoder().decode(Demo.self, from: Data(contentsOf: URL(fileURLWithPath: file))) else { return }
        timer?.invalidate(); watcher?.invalidate()
        trusted = true; current = d.current; screens = d.screens; selection = d.current; expanded = [d.current]
        let layout = saved[d.current] ?? [:]
        live = layout.mapValues { $0.map(\.key) }
        liveSpaces = layout.mapValues { $0.enumerated().map { LiveSpace(id: $0.offset + 1, bundle: $0.element.bundleID, window: $0.element.window) } }
    }

    var profiles: [String] {
        Set(sets.keys).union([current]).sorted { ($0.split(separator: "+").count, $0) < ($1.split(separator: "+").count, $1) }
    }

    // ponytail: monitors drawn left to right by x only; a monitor above or below the laptop
    // still lands in the row. Use the y position too if that layout ever matters.
    func displays(_ key: String) -> [String] {
        key.split(separator: "+").map(String.init).sorted { (screens[$0]?.x ?? 0) < (screens[$1]?.x ?? 0) }
    }

    func name(_ uuid: String) -> String {
        guard let s = screens[uuid] else { return String(localized: "Monitor \(String(uuid.prefix(4)))") }
        return s.builtin ? String(localized: "Laptop") : s.name
    }

    func title(_ key: String) -> String {
        let d = displays(key)
        return d.count == 1 && screens[d[0]]?.builtin == true ? String(localized: "Sam laptop") : d.map(name).joined(separator: " + ")
    }

    /// Names a Space on the bar now (one that is not in the save).
    func describe(_ s: LiveSpace) -> Entry {
        Entry(bundleID: s.bundle,
              app: s.bundle == desktopID ? "Biurko" : NSRunningApplication.runningApplications(withBundleIdentifier: s.bundle).first?.localizedName
                  ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: s.bundle)?.deletingPathExtension().lastPathComponent ?? s.bundle,
              title: "", window: s.window)
    }

    func spaceCount(_ key: String) -> Int { saved[key]?.values.map(\.count).reduce(0, +) ?? 0 }

    /// The connected set has a save and a tile differs from it (moved, missing, not saved): the
    /// same states the tiles show. A window that only got a new number (app reopened) is not a
    /// difference, its app still stands in its place.
    func differs(_ key: String) -> Bool {
        key == current && saved[key] != nil && PanelData(self, key: key).differs
    }

    func status(_ key: String) -> String {
        guard saved[key] != nil else { return key == current ? String(localized: "Podłączony, brak zapisu") : String(localized: "Brak zapisu") }
        guard key == current else { return String(localized: "Niepodłączony") }
        return differs(key) ? String(localized: "Podłączony, obecny układ jest inny niż zapis") : String(localized: "Podłączony, układ zgodny z zapisem")
    }

    /// Saves the current layout; asks first when it would replace an existing save. Auto-save
    /// does not come through here (it calls `storeLayout` itself). The panel look has its own
    /// two-step cover instead of the question (`ask: false`).
    func save(ask: Bool = true) {
        guard let l = sets[current]?.current else { askNew(); return }   // no selected layout: it gets a name first
        if ask {
            NSApp.activate(ignoringOtherApps: true)   // from the menu bar the app is not frontmost
            let alert = NSAlert()
            alert.messageText = String(localized: "Nadpisać układ „\(name(of: l))”?")
            alert.informativeText = String(localized: "Układ „\(name(of: l))” zestawu „\(title(current))” zostanie zastąpiony obecnym układem przestrzeni.")
            alert.addButton(withTitle: String(localized: "Nadpisz"))
            alert.addButton(withTitle: String(localized: "Anuluj")).keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        try? storeLayout(currentLayout()); refresh()
    }

    // MARK: Layouts of a set (docs/design-handoff-layouts.md, "Zachowanie")

    func layouts(_ key: String) -> [NamedLayout] { sets[key]?.layouts ?? [] }

    func name(of l: NamedLayout) -> String { l.name ?? String(localized: "Bez nazwy") }

    /// The layout the window shows for `key`: the one clicked in the sidebar, else the selected one.
    func viewed(_ key: String) -> NamedLayout? {
        if key == selection, let id = viewedID, let l = layouts(key).first(where: { $0.id == id }) { return l }
        return sets[key]?.current
    }

    /// Looking at a layout that is not the one on screen (or at a set that is not connected).
    func isPreview(_ key: String) -> Bool { key != current || viewed(key)?.id != sets[key]?.selected }

    /// Another layout of `key` already has this name (case ignored).
    func nameTaken(_ name: String, in key: String, except id: String? = nil) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces).lowercased()
        return layouts(key).contains { $0.id != id && $0.name?.lowercased() == n }
    }

    private func edit(_ key: String, _ change: (inout LayoutSet) -> Void) {
        var all = loadSets()
        guard var s = all[key] else { return }
        change(&s)
        all[key] = s.layouts.isEmpty ? nil : s
        try? writeSets(all)
        refresh()
    }

    func askNew() {
        newName = ""
        naming = Naming(first: layouts(current).isEmpty)
    }

    /// The screen now as a new layout of the connected set, selected from now on.
    func saveAsNew(_ name: String) {
        let n = NamedLayout(name: name.trimmingCharacters(in: .whitespaces), layout: currentLayout())
        var all = loadSets()
        all[current, default: LayoutSet(layouts: [], selected: n.id)].layouts.append(n)
        all[current]?.selected = n.id
        try? writeSets(all)
        selection = current; viewedID = nil; expanded.insert(current)
        refresh()
    }

    func rename(_ key: String, _ id: String, to name: String) {
        edit(key) { s in if let i = s.layouts.firstIndex(where: { $0.id == id }) { s.layouts[i].name = name.trimmingCharacters(in: .whitespaces) } }
    }

    func move(_ key: String, _ from: IndexSet, _ to: Int) { edit(key) { $0.layouts.move(fromOffsets: from, toOffset: to) } }

    /// Asks first. Deleting the layout on screen leaves the set with none selected (not the next
    /// one): auto-save would otherwise write this screen into a layout that is not on it.
    func deleteLayout(_ key: String, _ id: String) {
        let ls = layouts(key)
        guard let i = ls.firstIndex(where: { $0.id == id }) else { return }
        if UserDefaults.standard.bool(forKey: PanelKey.on) { deleting = DeleteRequest(key: key, layout: id); return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(localized: "Usunąć układ „\(name(of: ls[i]))”?")
        alert.informativeText = i + 1 < ls.count
            ? String(localized: "Tego nie da się cofnąć.") + " " + String(localized: "„\(name(of: ls[i + 1]))” przejdzie z pozycji \(i + 2) na \(i + 1).")
            : String(localized: "Tego nie da się cofnąć.")
        alert.addButton(withTitle: String(localized: "Usuń")).hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Anuluj")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        performDelete(key, id)
    }

    func performDelete(_ key: String, _ id: String) {
        let ls = layouts(key)
        guard let i = ls.firstIndex(where: { $0.id == id }) else { return }
        // The layout taking its place on the list (or the one before) becomes viewed / selected.
        let neighbor = ls.indices.contains(i + 1) ? ls[i + 1].id : i > 0 ? ls[i - 1].id : nil
        if key == selection, viewedID == id { viewedID = neighbor }
        edit(key) { s in
            s.layouts.removeAll { $0.id == id }
            if s.selected == id { s.selected = neighbor ?? "" }
        }
    }

    /// Layout shortcut (⌃⌥N) and a click on a layout in the menu bar: restores the layout at that
    /// position of the connected set, opening missing apps when the setting says so; a position
    /// with no layout beeps.
    func restorePosition(_ n: Int) {
        let ls = layouts(current)
        guard ls.indices.contains(n - 1) else { NSSound.beep(); return }
        restore(current, ls[n - 1].id, openApps: UserDefaults.standard.string(forKey: "layoutHotkeyMode") == "open")
    }

    // A layout's name field (sidebar row, rail row): the text typed so far, whether it may be
    // saved, and saving it.
    func draft(_ l: NamedLayout) -> String { drafts[l.id] ?? l.name ?? "" }

    /// Empty while renaming, or the name of another layout of the set.
    func draftInvalid(_ key: String, _ l: NamedLayout) -> Bool {
        let t = draft(l).trimmingCharacters(in: .whitespaces)
        return (renaming == l.id && t.isEmpty) || (!t.isEmpty && nameTaken(t, in: key, except: l.id))
    }

    /// Enter on a bad name keeps the field open (`keepIfBad`); leaving the field saves a good name
    /// and drops a bad one.
    /// The rename in progress, saved as if its field were left (a bad name drops it).
    func commitRenaming() {
        guard let id = renaming else { return }
        for (k, s) in sets { if let l = s.layouts.first(where: { $0.id == id }) { commitDraft(k, l, keepIfBad: false); return } }
        renaming = nil
    }

    func commitDraft(_ key: String, _ l: NamedLayout, keepIfBad: Bool) {
        let t = draft(l).trimmingCharacters(in: .whitespaces), bad = draftInvalid(key, l)
        if bad || t.isEmpty, keepIfBad { return }
        if !bad, !t.isEmpty, t != l.name { rename(key, l.id, to: t) }
        renaming = nil
        drafts[l.id] = nil
    }

    /// Restores layout `id` of the connected set; it is the selected one from now on.
    func restore(_ key: String, _ id: String, openApps: Bool = false) {
        guard key == current, !busy, trusted else { NSSound.beep(); return }
        let switched = sets[key]?.selected != id
        if switched { edit(key) { $0.selected = id } }
        if key == selection { viewedID = nil }
        restoreNow(openApps: openApps, switched: switched)
    }

    func delete(_ key: String) {
        var sets = loadSets()
        sets[key] = nil
        try? writeSets(sets)
        refresh()
    }

    func requestAccess() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    func setLoginItem(_ on: Bool) {
        do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() } catch { log("Start przy logowaniu: \(error)") }
        loginItem = SMAppService.mainApp.status == .enabled
    }

    /// Restores off the main thread; the "please wait" overlay shows only once a slow method
    /// (drag, full screen) starts, so the direct method runs without a red flash. `openApps`:
    /// launch the saved apps that are closed first ("Przywróć z brakującymi": its own button and
    /// shortcut; never the watcher's restore). `only`: open just that app (Open on a red tile).
    /// `switched`: another layout than the one on screen (its banner says "changed to").
    func restoreNow(openApps: Bool = false, only: String? = nil, switched: Bool = false) {
        guard !busy else { return }
        busy = true
        restoring = true   // the watcher skips its ticks from now on, not only once runRestore starts
        // One banner at a time: the quiet one says which layout; a slow method swaps in the red one.
        let info = sets[current]?.current.map { BannerInfo(name: $0.name, switched: switched, opening: openApps) }
        if let info { Overlay.show(red: false, info: info) }
        slowRestoreStarts = { DispatchQueue.main.async { if self.busy { Overlay.show(info: info) } } }
        DispatchQueue.global().async {
            runRestore(openApps: openApps, only: only)
            DispatchQueue.main.async {
                Overlay.finish(); self.busy = false; self.refresh()
                // A moment later (apps still opening, windows going full screen): did it all land?
                guard only == nil, let info else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + (openApps ? 3 : 1)) { self.checkResult(info) }
            }
        }
    }

    /// After a restore: Spaces of the layout still out of place, missing or not full screen
    /// (apps outside the layout do not count: "Leave" keeps them on purpose) show an orange banner.
    /// ponytail: a saved app that is closed warns after every plain restore; mute it if that nags.
    private func checkResult(_ info: BannerInfo) {
        guard !busy else { return }
        refresh()
        let n = PanelData(self, key: current).tiles.filter { [.moved, .missing, .noFullScreen].contains($0.state) }.count
        guard n > 0 else { return }
        log("Po przywróceniu różnice: \(n)")
        var i = info; i.problems = n
        Overlay.flash(i)
    }
}

/// Banner on every screen during a restore. Click-through, on every Space, above full-screen
/// apps. Red = Spaces are being moved, hands off (a slow method); quiet = which layout (the fast
/// one, too quick to notice otherwise). Stays at least `minimum`, then fades out.
enum Overlay {
    static let minimum: TimeInterval = 0.3   // ponytail: first guess, tune once used for a while
    private static var panels: [NSPanel] = []
    private static var shownAt = Date.distantPast
    private static var generation = 0   // which show() the panels are from

    /// `info`: the layout being restored, under the red banner's text or as the quiet one's title.
    /// With the panel look on, both are its banner (design RV-A).
    static func show(red: Bool = true, info: BannerInfo? = nil) {
        if panels.isEmpty { shownAt = Date() }   // red after the quiet one: the time counts from the first
        hide()
        generation += 1
        panels = NSScreen.screens.map { screen in
            let size = NSSize(width: 440, height: 96)   // the tallest banner; each sits at the bottom of it
            let panel = NSPanel(contentRect: NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.minY + 90,
                                                    width: size.width, height: size.height),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.ignoresMouseEvents = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.contentView = NSHostingView(rootView: RestoreBanner(red: red, info: info))
            panel.orderFrontRegardless()
            return panel
        }
    }

    /// A banner on its own for 2.5 s (the result after a restore), unless another one replaces it.
    static func flash(_ info: BannerInfo) {
        show(red: false, info: info)
        let shown = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { if generation == shown { finish() } }
    }

    static func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels = []
    }

    /// End of a restore: after `minimum` from the first banner, a 0.2 s fade (none with Reduce motion).
    static func finish() {
        let fading = panels
        panels = []   // a banner shown meanwhile is not taken down with these
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, minimum - Date().timeIntervalSince(shownAt))) {
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { fading.forEach { $0.orderOut(nil) }; return }
            NSAnimationContext.runAnimationGroup({ c in
                c.duration = 0.2
                fading.forEach { $0.animator().alphaValue = 0 }
            }, completionHandler: { fading.forEach { $0.orderOut(nil) } })
        }
    }
}

/// What the restore banner says: which layout, whether it replaces another one, apps opening.
struct BannerInfo {
    var name: String?   // nil = unnamed
    var switched: Bool
    var opening: Bool
    var problems: Int? = nil   // set: the result after a restore, this many Spaces not as saved
}

/// The banner in the look that is on now (it follows a change of the look while shown).
struct RestoreBanner: View {
    let red: Bool
    let info: BannerInfo?
    @AppStorage(PanelKey.on) private var panelLook = false

    var body: some View {
        let line = info.map { i in
            let name = i.name ?? String(localized: "Bez nazwy")
            return i.switched ? String(localized: "Zmieniono układ na „\(name)”") : String(localized: "Przywrócono układ „\(name)”")
        }
        let detail = info?.opening == true ? String(localized: "otwieram brakujące apki") : nil
        Group {
            if panelLook { PanelRestoreBanner(warning: red, info: info) }
            else if let n = info?.problems {
                LayoutBanner(title: String(localized: "Nie wszystko się ułożyło"),
                             detail: String(localized: "Różnice: \(n) · szczegóły w oknie SpaceDock"),
                             symbol: "exclamationmark.triangle.fill", color: Color.orange.opacity(0.95))
                    .frame(height: 72)
            }
            else if red { OverlayView(line: line).frame(height: line == nil ? 76 : 96) }
            else { LayoutBanner(title: line ?? "", detail: detail).frame(height: detail == nil ? 56 : 72) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

/// The quiet banner: which layout a restore puts on screen.
struct LayoutBanner: View {
    let title: String
    let detail: String?
    var symbol = "rectangle.split.3x1"
    var color = Color.black.opacity(0.72)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.headline).lineLimit(1)
                if let detail { Text(verbatim: detail).font(.callout).opacity(0.8) }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(color))
    }
}

/// CLI (`restore`, `restore-drag`, tests through tools/run-in-app.sh): the same overlay as the
/// app while `work` runs off the main thread.
func withOverlay(_ work: @escaping () -> Void) {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.finishLaunching()
    Overlay.show()
    var done = false
    DispatchQueue.global().async { work(); DispatchQueue.main.async { done = true } }
    while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    Overlay.hide()
}

struct OverlayView: View {
    var line: String? = nil   // which layout

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised.fill").font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text("Układam przestrzenie…").font(.headline)
                Text("Nie ruszaj myszy ani klawiatury, to potrwa kilka sekund.").font(.callout)
                if let line { Text(verbatim: line).font(.callout.weight(.semibold)).opacity(0.9).lineLimit(1) }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.92)))
    }
}

private var iconCache: [String: NSImage] = [:]

func appIcon(_ bundleID: String) -> NSImage {
    if let i = iconCache[bundleID] { return i }
    if bundleID == desktopID { return NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: String(localized: "Biurko"))! }
    let i = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
        ?? NSImage(systemSymbolName: "questionmark.app", accessibilityDescription: nil)!
    iconCache[bundleID] = i
    return i
}

struct SpacesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = Model()

    var body: some Scene {
        Window("SpaceDock", id: "main") {
            RootView().environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)   // ContentView draws the title itself, next to the window buttons
        .commands {
            CommandGroup(after: .appInfo) { CheckForUpdatesButton() }
            CommandGroup(replacing: .appSettings) { SettingsCommand().environmentObject(model) }
        }
        Settings {   // app menu → Settings… (⌘,), also from the menu bar icon
            SettingsPanel().environmentObject(model)
        }
        MenuBarExtra {
            MenuContent().environmentObject(model)
        } label: {
            // The "Template" suffix makes AppKit treat it as a template image (recolored for the bar).
            // Outside the bundle (swift run) there is no resource, so fall back to a system symbol.
            if let icon = NSImage(named: "MenuBarIconTemplate") {
                Image(nsImage: icon).accessibilityLabel("SpaceDock")
            } else {
                Image(systemName: "rectangle.split.3x1").accessibilityLabel("SpaceDock")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)   // LSUIElement: starts with no Dock icon or app menu
        _ = Updates.controller   // starts the daily update check
        // `-bannerTest warn|info|open`: the restore banner at once and for good (until the app
        // quits), to look at it and its animation; the look follows the panel setting.
        if let test = UserDefaults.standard.string(forKey: "bannerTest") {
            Overlay.show(red: test == "warn", info: BannerInfo(name: "Praca", switched: test != "restore", opening: test == "open",
                                                               problems: test == "result" ? 2 : nil))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// App menu → Settings… (⌘,), in the look that is on.
struct SettingsCommand: View {
    @EnvironmentObject var model: Model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Ustawienia…") { showSettings(model, openWindow: openWindow, openSettings: openSettings) }
            .keyboardShortcut(",")
    }
}

struct MenuContent: View {
    @EnvironmentObject var model: Model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("autoSave") private var autoSave = false
    @AppStorage("autoRestore") private var autoRestore = true

    var body: some View {
        Text("Teraz: \(model.title(model.current))")
        if model.differs(model.current) {
            Label(model.status(model.current), systemImage: "exclamationmark.triangle")
        } else {
            Text(model.status(model.current))
        }
        if !model.trusted { Text("Automat wyłączony: brak uprawnienia Dostępność") }
        Divider()
        let layouts = model.layouts(model.current)
        if !layouts.isEmpty {
            Section("Układy") {
                ForEach(Array(layouts.enumerated()), id: \.element.id) { i, l in
                    // A tick on the layout on screen; a click restores it (and selects it).
                    Toggle(isOn: Binding(get: { model.sets[model.current]?.selected == l.id },
                                         set: { _ in model.restorePosition(i + 1) })) {
                        Text(verbatim: "\(i + 1). \(model.name(of: l))" + (Hotkeys.layoutLabel(i + 1).map { "    " + $0 } ?? ""))
                    }
                    .disabled(model.busy || !model.trusted)
                }
            }
        }
        Button("Pokaż okno") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Przywróć") { model.restoreNow() }
            .disabled(model.saved[model.current] == nil || model.busy || !model.trusted)
        Button("Przywróć z brakującymi") { model.restoreNow(openApps: true) }
            .disabled(model.saved[model.current] == nil || model.busy || !model.trusted)
            .help("Najpierw otwiera zamknięte apki z zapisu, potem ustawia przestrzenie. Apki startują jak zwykle: ich stanu sprzed zamknięcia (np. kart przeglądarki) SpaceDock nie przywraca")
        if let l = model.sets[model.current]?.current {
            Button("Zapisz „\(model.name(of: l))”") { model.save() }
        }
        Button("Zapisz jako nowy…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            model.askNew()
        }
        Toggle("Przywracaj automatycznie", isOn: $autoRestore)
        Toggle("Zapisuj automatycznie", isOn: $autoSave)
        Button("Pokaż log") { NSWorkspace.shared.open(logFile) }
        CheckForUpdatesButton()
        Button("Ustawienia…") { showSettings(model, openWindow: openWindow, openSettings: openSettings) }
        Button("Wesprzyj na Ko-fi…") { NSWorkspace.shared.open(supportURL) }
        Divider()
        Button("Zakończ") { NSApp.terminate(nil) }
    }
}

/// Settings in the look that is on: the settings window, or in the neon look its own window
/// inside the main one. Used by ⌘, and the menu bar's "Settings…".
@MainActor func showSettings(_ model: Model, openWindow: OpenWindowAction, openSettings: OpenSettingsAction) {
    NSApp.activate(ignoringOtherApps: true)
    if UserDefaults.standard.bool(forKey: PanelKey.on) {
        openWindow(id: "main")
        model.panelSettingsOpen = true
    } else {
        openSettings()
    }
}

/// The normal look, or the hidden panel look (Panel.swift) once the easter egg has unlocked it.
struct RootView: View {
    @EnvironmentObject var model: Model
    @AppStorage(PanelKey.on) private var panelOn = false

    var body: some View {
        Group {
            if panelOn { PanelView() } else { ContentView() }
        }
        .preferredColorScheme(panelOn ? .dark : nil)
        .sheet(item: $model.naming) { n in
            Group { if panelOn { PanelNameSheet(first: n.first) } else { NameSheet(first: n.first) } }.environmentObject(model)
        }
        .sheet(item: $model.deleting) { d in PanelDeleteSheet(request: d).environmentObject(model) }
        // While the window is open the app is a regular one: Dock icon and its own menu bar
        // (SpaceDock → Settings…). Closed, it goes back to the menu bar icon only.
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: Model

    private var sidebarToggle: some View {
        Button {
            withAnimation { model.columns = model.columns == .detailOnly ? .all : .detailOnly }
        } label: {
            Image(systemName: "sidebar.left").font(.system(size: 15, weight: .regular))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(model.columns == .detailOnly ? "Pokaż listę zestawów" : "Schowaj listę zestawów")
        .accessibilityLabel(model.columns == .detailOnly ? "Pokaż listę zestawów" : "Schowaj listę zestawów")
    }

    /// One list selection for set rows (`key`) and layout rows (`key` + newline + layout id).
    private var listSelection: Binding<String?> {
        Binding(get: {
            guard let k = model.selection else { return nil }
            return model.viewed(k).map { k + "\n" + $0.id } ?? k
        }, set: { v in
            guard let v else { return }
            let parts = v.split(separator: "\n", maxSplits: 1).map(String.init)
            model.selection = parts[0]
            model.viewedID = parts.count > 1 ? parts[1] : nil
        })
    }

    var body: some View {
        // Title row of our own (the system title bar is hidden): "SpaceDock" right after the
        // window buttons, like foobar2000, then the sidebar toggle the hidden toolbar no longer has.
        VStack(spacing: 0) {
        ZStack {
            HStack {
                Text("SpaceDock").font(.headline)
                Spacer()
            }
            .padding(.leading, 82)
            ShuttleEgg()   // easter egg, in the middle of the title row
        }
        .frame(height: 30)
        Divider()
        NavigationSplitView(columnVisibility: $model.columns) {
            List(selection: listSelection) { ForEach(model.profiles, id: \.self) { key in
                DisclosureGroup(isExpanded: Binding(get: { model.expanded.contains(key) },
                                                    set: { if $0 { model.expanded.insert(key) } else { model.expanded.remove(key) } })) {
                    ForEach(Array(model.layouts(key).enumerated()), id: \.element.id) { i, l in
                        LayoutRow(key: key, layout: l, position: i + 1).tag(key + "\n" + l.id)
                    }
                    .onMove { model.move(key, $0, $1) }
                    if key == model.current {
                        Button { model.askNew() } label: { Label("Zapisz jako nowy…", systemImage: "plus").lineLimit(1) }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .disabled(!model.trusted)
                    }
                } label: {
                // On the title's line, like the disclosure arrow before it.
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: key.contains("+") ? "display.2" : "laptopcomputer")
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.title(key))
                        (Text("Układy: \(model.layouts(key).count) · ") + Text("\(model.spaceCount(key)) przestrzeni"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if model.differs(key) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Obecny układ jest inny niż zapis")
                            .accessibilityLabel("Obecny układ jest inny niż zapis")
                    }
                    if key == model.current {
                        // Its own color, so it still stands out on the selected (accent) row.
                        Text("TERAZ")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green))
                            .help("Ten zestaw monitorów jest teraz podłączony")
                    }
                }
                .padding(.vertical, 2)
                .tag(key)
                }
            } }
            .safeAreaInset(edge: .top) {
                // The toggle belongs to the sidebar: its own header row, at the column's right edge.
                HStack {
                    Text("Zestawy monitorów").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    sidebarToggle
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .safeAreaInset(edge: .bottom) { SidebarStatus().padding(12) }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 420)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                if let key = model.selection {
                    ProfileView(key: key)
                } else {
                    Text("Wybierz zestaw monitorów").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .safeAreaInset(edge: .top) {
                if model.columns == .detailOnly {   // sidebar hidden: the way back in, top left
                    HStack { sidebarToggle; Spacer() }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                }
            }
        }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 780, minHeight: 420)
    }
}

struct SettingsPanel: View {
    private func modePicker(_ value: Binding<Bool>) -> some View {
        Picker("", selection: value) {
            Text("Ręcznie").tag(false)
            Text("Automatycznie").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @EnvironmentObject var model: Model
    @AppStorage("autoSave") private var autoSave = false
    @AppStorage("autoRestore") private var autoRestore = true
    @AppStorage("restoreMethod") private var restoreMethod = "bridge"
    @AppStorage("outsideApps") private var outsideApps = "leave"
    @AppStorage("layoutHotkeyMode") private var layoutHotkeyMode = "move"
    @AppStorage(Hotkeys.layoutsKey) private var layoutKeys = ""
    @ObservedObject private var hotkeys = Hotkeys.shared
    @AppStorage(PanelKey.unlocked) private var panelUnlocked = false
    @AppStorage(PanelKey.on) private var panelOn = false
    @AppStorage(PanelKey.theme) private var panelTheme = 1
    @AppStorage("settingsTab") private var settingsTab = "general"   // the panel look opens "shortcuts" directly
    @Environment(\.openWindow) private var openWindow

    /// Settings window (⌘, or the gear under the sets): three tabs, the sidebar keeps only the
    /// watcher's state. Grids keep labels in one column, so the switches line up.
    var body: some View {
        TabView(selection: $settingsTab) {
            tab {
                watcherState
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Text("Przywracanie")
                        modePicker($autoRestore)
                            .help("Automatycznie: po podłączeniu lub odłączeniu monitora. Ręcznie: przycisk Przywróć")
                    }
                    GridRow {
                        Text("Zapis")
                        modePicker($autoSave)
                            .help("Automatycznie: zapisuje zmianę kolejności, gdy stoi 5 s, nigdy tuż po zmianie monitorów")
                    }
                    GridRow {
                        Text("Metoda")
                        Picker("", selection: $restoreMethod) {
                            Text("Przeciąganie").tag("drag").selectionDisabled(!dragAvailable)
                            Text("Pełny ekran").tag("fullscreen")
                            Text("Bezpośrednio").tag("bridge")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .help("Przeciąganie: Mission Control i wirtualna mysz Karabinera. Pełny ekran: bez Karabinera, okna na chwilę wychodzą z pełnego ekranu, biurka zostają. Bezpośrednio: prywatna funkcja macOS 26+, bez myszy i Karabinera, ułamek sekundy")
                    }
                    if !dragAvailable {
                        GridRow {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            Text("Przeciąganie wymaga Karabiner-Elements")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    GridRow {
                        Text("Apki spoza układu")
                        Picker("", selection: $outsideApps) {
                            Text("Zostaw").tag("leave")
                            Text("Schowaj").tag("hide")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    GridRow {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        Text("Schowaj: przy każdym przywróceniu apki pełnoekranowe spoza układu wychodzą z pełnego ekranu i są minimalizowane. Automat schowa też świeżo otwartą, niezapisaną apkę. Apek nigdy nie zamykamy.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tabItem { Label("Ogólne", systemImage: "gearshape") }
            .tag("general")

            tab {
                Text("Działają z każdej apki. Domyślnie bez skrótów.").foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                    GridRow {
                        Text("Skrót: zapis")
                        ShortcutField(.save)
                    }
                    GridRow {
                        Text("Skrót: przywróć")
                        ShortcutField(.restore)
                    }
                    GridRow {
                        Text("Skrót: przywróć z brakującymi")
                        ShortcutField(.restoreOpen)
                    }
                }
                Divider()
                Text("Układy").font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                    GridRow {
                        Text("Skróty układów")
                        LayoutModifierField()
                    }
                    GridRow(alignment: .top) {
                        Text("Skrót układu")
                        Picker("", selection: $layoutHotkeyMode) {
                            Text("tylko przestawia przestrzenie").tag("move")
                            Text("przywraca z brakującymi apkami").tag("open")
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }
                }
                Text("Numer to pozycja układu na liście obecnego zestawu: ⌃⌥1 pierwszy, ⌃⌥2 drugi. Numer bez układu daje sygnał dźwiękowy.")
                    .font(.caption).foregroundStyle(.secondary)
                if !layoutKeys.isEmpty, Hotkeys.layoutsCommandOnly() {
                    Label("⌘1–9 przełącza karty w przeglądarkach i okna w IntelliJ. SpaceDock przejmie te skróty we wszystkich apkach. Dodaj ⌃ albo ⌥.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                if hotkeys.layoutsTaken {
                    Text("Część tych skrótów zajmuje inna apka, wybierz inne modyfikatory.").font(.caption).foregroundStyle(.orange)
                }
            }
            .tabItem { Label("Skróty", systemImage: "keyboard") }
            .tag("shortcuts")

            tab {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Text("Język")
                        Picker("", selection: Binding(get: appLanguage, set: setAppLanguage)) {
                            Text("Jak w systemie").tag("")
                            Divider()
                            Text(verbatim: "Polski").tag("pl")
                            Text(verbatim: "English").tag("en")
                            Text(verbatim: "Español").tag("es")
                            Text(verbatim: "中文（简体）").tag("zh-Hans")
                        }
                        .labelsHidden()
                        .disabled(model.busy)
                        .help("Zmiana uruchamia apkę ponownie")
                    }
                    if panelUnlocked {   // the hidden look, once the shuttle has been clicked 10 times
                        GridRow {
                            Text("Wygląd")
                            Picker("", selection: Binding(get: { panelOn }, set: { on in
                                panelOn = on
                                guard on else { return }   // the settings follow the look: the neon window in the main one
                                NSApp.windows.first { $0.identifier?.rawValue.contains("Settings") == true }?.close()
                                openWindow(id: "main")
                                model.panelSettingsOpen = true
                            })) {
                                Text("Zwykły").tag(false)
                                Text("Neon").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        GridRow {
                            Text("Motyw")
                            Picker("", selection: $panelTheme) {
                                ForEach(1...3, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .disabled(!panelOn)
                        }
                    }
                }
                Toggle("Uruchamiaj przy logowaniu", isOn: Binding(get: { model.loginItem }, set: { model.setLoginItem($0) }))
                AutoUpdateToggle()
                Divider()
                Button { NSWorkspace.shared.open(supportURL) } label: {
                    Label("Wesprzyj na Ko-fi", systemImage: "cup.and.saucer.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1, green: 0.37, blue: 0.36))   // Ko-fi's coral
            }
            .tabItem { Label("Apka", systemImage: "macwindow") }
            .tag("app")
        }
        .font(.callout)
        .frame(width: 460)
    }

    private func tab(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var watcherState: some View {
        if model.trusted {
            Label("Automat pilnuje monitorów", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Label("Automat wyłączony: brak uprawnienia Dostępność", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Button("Nadaj uprawnienie…") { model.requestAccess() }
        }
    }
}

/// Under the sets in the sidebar: the watcher's state and the way to the settings window.
struct SidebarStatus: View {
    @EnvironmentObject var model: Model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 8) {
            if model.trusted {
                Label("Automat pilnuje monitorów", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button { model.requestAccess() } label: {
                    Label("Automat wyłączony: nadaj uprawnienie", systemImage: "exclamationmark.triangle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
            }
            Spacer(minLength: 4)
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: { Image(systemName: "gearshape") }
            .buttonStyle(.borderless)
            .help("Ustawienia")
        }
        .font(.callout)
        .lineLimit(1)
    }
}

struct ProfileView: View {
    @EnvironmentObject var model: Model
    let key: String

    var body: some View {
        let viewed = model.viewed(key)
        let preview = viewed != nil && model.isPreview(key)
        // Scrolls in a short window instead of squeezing the monitors (tiles spilled out of them).
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(viewed.map(model.name(of:)) ?? model.title(key)).font(.title2.bold())
                            .foregroundStyle(viewed != nil && viewed?.name == nil ? .secondary : .primary)
                        if viewed != nil { preview ? AnyView(previewCapsule) : AnyView(onScreenCapsule) }
                    }
                    if preview || viewed == nil && model.sets[key] != nil {
                        Text(model.title(key)).foregroundStyle(.secondary)
                    } else if model.differs(key) {
                        // Orange, not yellow: yellow text is unreadable on the light background.
                        Label(model.status(key), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Text(model.status(key)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if key == model.current {
                    Button("Zapisz") { model.save() }
                        .disabled(preview)
                        .help(preview ? "Zapis działa tylko na układ na ekranie" : "Zapisuje obecne przestrzenie do tego układu")
                    let restore = { (open: Bool) in
                        if preview, let viewed { model.restore(key, viewed.id, openApps: open) } else { model.restoreNow(openApps: open) }
                    }
                    let restoreButton = Button(model.busy ? "Przywracam…" : "Przywróć") { restore(false) }
                        .disabled(viewed == nil || model.busy || !model.trusted)
                        .help(model.trusted ? "Ustaw przestrzenie jak w zapisie" : "Wymaga uprawnienia Dostępność dla tej apki")
                    if preview { restoreButton.buttonStyle(.borderedProminent) } else { restoreButton }
                    Button("Przywróć z brakującymi") { restore(true) }
                        .disabled(viewed == nil || model.busy || !model.trusted)
                        .help("Najpierw otwiera zamknięte apki z zapisu, potem ustawia przestrzenie. Apki startują jak zwykle: ich stanu sprzed zamknięcia (np. kart przeglądarki) SpaceDock nie przywraca")
                }
            }
            if preview, key == model.current, let viewed { banner(viewed) }
            if let viewed {
                // The panel look's states (ok, moved, missing, …): one computation for both looks.
                HStack(alignment: .top, spacing: 16) {
                    ForEach(PanelData(model, key: key, layout: viewed.layout).monitors, id: \.uuid) { m in
                        MonitorView(uuid: m.uuid, name: model.name(m.uuid), tiles: m.tiles)
                    }
                }
            } else if model.sets.isEmpty {
                FirstSteps()
            } else if model.sets[key] != nil {
                Text("Kliknij układ na liście, żeby zobaczyć go tutaj.").foregroundStyle(.secondary)
            } else {
                Text("Ten zestaw nie ma jeszcze żadnego układu. Ułóż przestrzenie i kliknij „Zapisz”.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading) }
    }

    private var onScreenCapsule: some View {
        Text("NA EKRANIE")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.green))
            .help("Ten układ jest teraz na ekranie")
    }

    private var previewCapsule: some View {
        Text("PODGLĄD")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1))
            .help("Oglądasz zapisany układ, nie to, co jest na ekranie")
    }

    /// Preview of a layout that is not on screen: what you look at, what is on screen, the way back.
    private func banner(_ viewed: NamedLayout) -> some View {
        let onScreen = model.sets[key]?.current
        return HStack(spacing: 10) {
            Image(systemName: "eye")
            if let onScreen {
                Text("Oglądasz zapisany układ **„\(model.name(of: viewed))”**. Na ekranie jest **„\(model.name(of: onScreen))”**. Kolory pokazują, czym różni się od ekranu.")
            } else {
                Text("Oglądasz zapisany układ **„\(model.name(of: viewed))”**. Kolory pokazują, czym różni się od ekranu.")
            }
            Spacer(minLength: 8)
            if let onScreen {
                Button("Wróć do „\(model.name(of: onScreen))”") { model.viewedID = nil }.buttonStyle(.link)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1))
    }
}

/// A layout in the sidebar tree: position, name (a field when unnamed or being renamed), a green
/// tick on the one on screen, ⋯ with rename and delete; drag to reorder.
struct LayoutRow: View {
    @EnvironmentObject var model: Model
    @AppStorage(Hotkeys.layoutsKey) private var layoutKeys = ""   // redraws the shortcut label when it changes
    @FocusState private var focused: Bool
    let key: String
    let layout: NamedLayout
    let position: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(position)").monospacedDigit().foregroundStyle(.secondary).frame(width: 14, alignment: .trailing)
            if layout.name == nil || model.renaming == layout.id { field } else {
                Text(verbatim: layout.name ?? "").lineLimit(1).truncationMode(.tail).layoutPriority(1)
            }
            Spacer(minLength: 4)
            if key == model.current, let s = Hotkeys.layoutLabel(position) {
                Text(verbatim: s).font(.system(size: 11)).foregroundStyle(.tertiary).fixedSize()
            }
            if key == model.current, model.sets[key]?.selected == layout.id {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .font(.system(size: 14))
                    .help("Ten układ jest teraz na ekranie")
                    .accessibilityLabel("Na ekranie")
            }
            Menu {
                Button("Zmień nazwę…") { model.commitRenaming(); model.drafts[layout.id] = layout.name ?? ""; model.renaming = layout.id }
                Button("Usuń układ…", role: .destructive) { model.deleteLayout(key, layout.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Zmień nazwę albo usuń")
        }
        .frame(minHeight: 28)
    }

    private var invalid: Bool { model.draftInvalid(key, layout) }

    private var field: some View {
        // Leaving the field saves too (no Enter needed); leaving it with a bad name drops the edit.
        TextField("Nadaj nazwę", text: Binding(get: { model.draft(layout) }, set: { model.drafts[layout.id] = $0 }),
                  onEditingChanged: { editing in if !editing { model.commitDraft(key, layout, keepIfBad: false) } },
                  onCommit: { model.commitDraft(key, layout, keepIfBad: true) })
            .textFieldStyle(.roundedBorder)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.red, lineWidth: invalid ? 1.5 : 0))
            .onExitCommand { model.renaming = nil; model.drafts[layout.id] = nil }
            .focused($focused)
            .onAppear { focusAtEnd($focused) }
    }

}

/// Puts the caret in a name field that just appeared, at the end of the text (macOS selects it
/// all when a field gets focus).
@MainActor func focusAtEnd(_ focus: FocusState<Bool>.Binding) {
    DispatchQueue.main.async {
        focus.wrappedValue = true
        DispatchQueue.main.async { (NSApp.keyWindow?.firstResponder as? NSTextView)?.moveToEndOfDocument(nil) }
    }
}

/// "Save as new" and the first save of a set: the name is required and unique in the set.
struct NameSheet: View {
    @EnvironmentObject var model: Model
    let first: Bool

    var body: some View {
        let t = model.newName.trimmingCharacters(in: .whitespaces)
        let taken = model.nameTaken(t, in: model.current)
        VStack(alignment: .leading, spacing: 12) {
            Text(first ? "Nazwij pierwszy układ tego zestawu" : "Zapisz obecny układ jako nowy").font(.headline)
            if first { Text("\(model.title(model.current)) nie ma jeszcze żadnego układu.").foregroundStyle(.secondary) }
            TextField("np. Praca", text: $model.newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if !t.isEmpty, !taken { model.saveAsNew(t); model.naming = nil } }
            if taken { Text("Ten zestaw ma już układ „\(t)”.").font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Anuluj") { model.naming = nil }.keyboardShortcut(.cancelAction)
                Button("Zapisz") { model.saveAsNew(t); model.naming = nil }
                    .keyboardShortcut(.defaultAction)
                    .disabled(t.isEmpty || taken)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

/// First launch (nothing saved yet): the two steps, each ticked off once done.
struct FirstSteps: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pierwsze kroki").font(.headline)
            step(1, done: model.trusted,
                 "Nadaj uprawnienie Dostępność. Bez niego SpaceDock nie przestawi przestrzeni ani nie przeczyta tytułów okien.") {
                Button("Nadaj uprawnienie…") { model.requestAccess() }
            }
            step(2, done: false,
                 "Ułóż przestrzenie tak, jak lubisz, i zapisz. Po podłączeniu lub odłączeniu monitora SpaceDock ułoży je tak samo.") {
                Button("Zapisz obecny układ") { model.save() }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func step(_ n: Int, done: Bool, _ text: LocalizedStringKey, @ViewBuilder action: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 6) {
                // No fixedSize(vertical:) here: the split view's first layout proposes a very narrow width,
                // the text then wrapped into a column thousands of points tall, and AppKit saved
                // those column heights, so the window opened with its top part out of sight.
                Text(text).foregroundStyle(done ? .secondary : .primary)
                if !done { action() }
            }
        }
    }
}

struct MonitorView: View {
    @EnvironmentObject var model: Model
    let uuid: String
    let name: String
    let tiles: [PanelTile]

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if tiles.isEmpty {
                    Text("Tylko biurka").font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Array(tiles.enumerated()), id: \.offset) { i, t in
                            SpaceTile(index: i + 1, tile: t, keyed: model.kbMonitor == uuid && model.kbTile == i)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.secondary.opacity(0.35), lineWidth: 2))
            .overlay {   // framed by ← / →
                if model.kbMonitor == uuid { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 3).padding(-4) }
            }
            Text(name).font(.headline)
        }
        // One tile wide at least (120 + padding): the grid wraps tiles into more rows instead, so
        // with 2–3 monitors the detail does not crowd out the sidebar.
        .frame(minWidth: 140)
    }
}

struct SpaceTile: View {
    @EnvironmentObject var model: Model
    let index: Int
    let tile: PanelTile
    var keyed = false   // picked with the keyboard (the same ring as a click; red with a note when Enter can't go there)
    private var entry: Entry { tile.entry }

    /// Yellow text is unreadable on the light background: a darker yellow there.
    private static let yellow = Color(nsColor: NSColor(name: nil) {
        $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .systemYellow : NSColor(red: 0.62, green: 0.46, blue: 0, alpha: 1)
    })

    /// Caption and color for a tile that differs from the bar now: red = nothing behind it
    /// (app closed, no desktop, window not full screen), yellow = in the wrong place, blue = not
    /// in the save. Always with words, not color alone.
    private var mark: (text: String, color: Color)? {
        switch tile.state {
        case .ok: nil
        case .moved: (String(localized: "Przestawione") + " › \(tile.now)", Self.yellow)
        case .unsaved: (String(localized: "Nie zapisane"), .blue)
        case .missing: (entry.isDesktop ? String(localized: "Brak biurka") : String(localized: "Nie otwarte"), .red)
        case .noFullScreen: (String(localized: "Nie na pełnym ekranie"), .red)
        }
    }
    private var name: String { entry.isDesktop ? String(localized: "Biurko") : entry.app }   // saves store the Polish word

    var body: some View {
        // Window title and number as saved: what a restore matches the live windows by
        // (number first, then title), e.g. to tell two Brave windows apart.
        VStack(spacing: 3) {
            Image(nsImage: appIcon(entry.bundleID)).resizable().frame(width: 32, height: 32)
            Text(name).font(.caption).lineLimit(1).truncationMode(.tail)
            if !entry.title.isEmpty {
                Text(entry.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
            }
            if let mark {
                Text(verbatim: mark.text).font(.caption2.weight(.semibold)).foregroundStyle(mark.color).lineLimit(1)
            } else if let w = entry.window {
                Text(verbatim: "#\(w)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            }
        }
        .opacity(tile.state == .missing ? 0.55 : 1)   // a saved place with nothing behind it now
        .padding(.horizontal, 6)
        .frame(width: 120, height: 96)
        .background(RoundedRectangle(cornerRadius: 8).fill(.background))
        .overlay {
            if let mark { RoundedRectangle(cornerRadius: 8).strokeBorder(mark.color, lineWidth: 2) }
        }
        .overlay(alignment: .topLeading) {
            Text("\(index)").font(.caption2.bold()).foregroundStyle(.secondary).padding(5)
        }
        .overlay(alignment: .topTrailing) {
            // A red app tile: open the app (if closed), full screen, and the restore puts it in place.
            // Not in a preview: it restores the layout on screen, not the one looked at.
            if !entry.isDesktop, tile.state == .missing || tile.state == .noFullScreen, !model.isPreview(model.selection ?? model.current) {
                Button { model.restoreNow(openApps: true, only: entry.bundleID) } label: {
                    Image(systemName: "arrow.up.forward.app").font(.system(size: 15))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .padding(4)
                .disabled(model.busy || !model.trusted)
                .help("Otwórz, włącz pełny ekran i ustaw jak w zapisie (przywraca cały układ)")
            }
        }
        .overlay {   // picked by a click or the keyboard: a ring just outside the tile, so a colored mark stays visible
            if keyed || (model.kbTile == nil && tile.space != nil && tile.space == model.pickedSpace) {
                RoundedRectangle(cornerRadius: 10).strokeBorder(keyed && model.kbNote != nil ? Color.red : Color.primary, lineWidth: 2).padding(-4)
            }
        }
        .overlay(alignment: .bottom) {   // why Enter did not go there
            if keyed, let note = model.kbNote {
                Text(LocalizedStringKey(note)).font(.caption2.weight(.semibold)).foregroundStyle(.white).lineLimit(1).fixedSize()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .offset(y: 12)
            }
        }
        .zIndex(keyed ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {   // double click: show this Space (its app, full screen)
            if let id = tile.space { DispatchQueue.global().async { _ = goTo(id) } }
        }
        .simultaneousGesture(TapGesture().onEnded { model.kbTile = nil; model.kbNote = nil; if let id = tile.space { model.pickedSpace = id } })
        .help(tile.space == nil ? (entry.title.isEmpty ? name : "\(name) — \(entry.title)")
              : (entry.title.isEmpty ? name : "\(name) — \(entry.title)") + "\n" + String(localized: "Kliknij dwa razy, żeby przejść do tej przestrzeni"))
    }
}
