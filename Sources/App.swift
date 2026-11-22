import SwiftUI
import AppKit
import ServiceManagement

// `spaces-layout app` (or the .app bundle): window with the saved Spaces per monitor set,
// plus a menu bar icon. Reading and saving need no Accessibility; restore and the watcher do.

let logFile = movedFromOldName("spaces-layout.log", "SpaceDock.log", in: "Library/Logs")

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

final class Model: ObservableObject {
    @Published var saved: [String: Layout] = [:]
    @Published var current = ""
    @Published var live: [String: [String]] = [:]
    @Published var liveSpaces: [String: [LiveSpace]] = [:]   // bars now, for the saved-vs-live tiles
    @Published var screens = (try? JSONDecoder().decode([String: ScreenInfo].self, from: Data(contentsOf: screensFile))) ?? [:]
    @Published var selection: String?
    @Published var busy = false
    @Published var columns = NavigationSplitViewVisibility.all   // sidebar shown or hidden (@State needs a macro plugin the CLI toolchain lacks)
    @Published var trusted = AXIsProcessTrusted()
    @Published var loginItem = SMAppService.mainApp.status == .enabled
    private var timer: Timer?
    private var watcher: Timer?

    init() {
        refresh()
        selection = current
        timer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let t = AXIsProcessTrusted()
        if t != trusted { trusted = t }
        if t, watcher == nil {
            watcher = startWatch(autoSave: { UserDefaults.standard.bool(forKey: "autoSave") },
                                 autoRestore: { UserDefaults.standard.object(forKey: "autoRestore") as? Bool ?? true },
                                 restore: { [weak self] in self?.restoreNow() })
        }
        let all = loadAll(), key = profileKey(), order = liveAppOrder()
        if all != saved { saved = all }
        if key != current { current = key }
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

    var profiles: [String] {
        Set(saved.keys).union([current]).sorted { ($0.split(separator: "+").count, $0) < ($1.split(separator: "+").count, $1) }
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

    /// Tiles per display: for the connected set the save next to the bars now (orange marks for
    /// Spaces not saved and saved ones not open), otherwise just the save.
    func tiles(_ key: String) -> [String: [Tile]] {
        guard let layout = saved[key] else { return [:] }
        guard key == current else { return layout.mapValues { $0.map { Tile(entry: $0, mark: .none) } } }
        return layoutDiff(saved: layout, live: liveSpaces, describe: describe)
    }

    /// Names a Space on the bar now (one that is not in the save).
    func describe(_ s: LiveSpace) -> Entry {
        Entry(bundleID: s.bundle,
              app: s.bundle == desktopID ? "Biurko" : NSRunningApplication.runningApplications(withBundleIdentifier: s.bundle).first?.localizedName ?? s.bundle,
              title: "", window: s.window)
    }

    func spaceCount(_ key: String) -> Int { saved[key]?.values.map(\.count).reduce(0, +) ?? 0 }

    /// The connected set has a save and the Spaces now are in another order (or other windows).
    func differs(_ key: String) -> Bool {
        key == current && saved[key].map { $0.mapValues { $0.map(\.key) } != live } ?? false
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
        if ask, saved[current] != nil {
            NSApp.activate(ignoringOtherApps: true)   // from the menu bar the app is not frontmost
            let alert = NSAlert()
            alert.messageText = String(localized: "Nadpisać zapisany układ?")
            alert.informativeText = String(localized: "Zapis dla zestawu „\(title(current))” zostanie zastąpiony obecnym układem przestrzeni.")
            alert.addButton(withTitle: String(localized: "Nadpisz"))
            alert.addButton(withTitle: String(localized: "Anuluj")).keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        try? storeLayout(currentLayout()); refresh()
    }

    func delete(_ key: String) {
        var all = loadAll()
        all[key] = nil
        try? writeAll(all)
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
    /// (drag, full screen) starts, so the direct method runs without a red flash.
    func restoreNow() {
        guard !busy else { return }
        busy = true
        restoring = true   // the watcher skips its ticks from now on, not only once runRestore starts
        slowRestoreStarts = { DispatchQueue.main.async { if self.busy { Overlay.show() } } }
        DispatchQueue.global().async {
            runRestore()
            DispatchQueue.main.async { Overlay.hide(); self.busy = false; self.refresh() }
        }
    }
}

/// "Please wait" banner on every screen while Spaces are being moved. Click-through, on every
/// Space, above full-screen apps.
enum Overlay {
    private static var panels: [NSPanel] = []

    static func show() {
        hide()
        panels = NSScreen.screens.map { screen in
            let size = NSSize(width: 440, height: 76)
            let panel = NSPanel(contentRect: NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.minY + 90,
                                                    width: size.width, height: size.height),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.ignoresMouseEvents = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.contentView = NSHostingView(rootView: OverlayView())
            panel.orderFrontRegardless()
            return panel
        }
    }

    static func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels = []
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
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised.fill").font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text("Układam przestrzenie…").font(.headline)
                Text("Nie ruszaj myszy ani klawiatury, to potrwa kilka sekund.").font(.callout)
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
        .commands { CommandGroup(after: .appInfo) { CheckForUpdatesButton() } }
        Settings {   // app menu → Settings… (⌘,), also from the menu bar icon
            SettingsPanel().environmentObject(model).padding(20).frame(width: 380)
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
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
        Button("Pokaż okno") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Przywróć") { model.restoreNow() }
            .disabled(model.saved[model.current] == nil || model.busy || !model.trusted)
        Button("Zapisz obecny układ") { model.save() }
        Toggle("Przywracaj automatycznie", isOn: $autoRestore)
        Toggle("Zapisuj automatycznie", isOn: $autoSave)
        Button("Pokaż log") { NSWorkspace.shared.open(logFile) }
        CheckForUpdatesButton()
        Button("Ustawienia…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        Divider()
        Button("Zakończ") { NSApp.terminate(nil) }
    }
}

/// The normal look, or the hidden panel look (Panel.swift) once the easter egg has unlocked it.
struct RootView: View {
    @AppStorage(PanelKey.on) private var panelOn = false

    var body: some View {
        Group {
            if panelOn { PanelView() } else { ContentView() }
        }
        .preferredColorScheme(panelOn ? .dark : nil)
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
            List(model.profiles, id: \.self, selection: $model.selection) { key in
                HStack(spacing: 10) {
                    Image(systemName: key.contains("+") ? "display.2" : "laptopcomputer")
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.title(key))
                        Text("\(model.spaceCount(key)) przestrzeni")
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
                .contextMenu {
                    if model.saved[key] != nil {
                        Button("Usuń zapis", role: .destructive) { model.delete(key) }
                    }
                }
            }
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
            .safeAreaInset(edge: .bottom) { SettingsPanel().padding(12) }
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
    @AppStorage(PanelKey.unlocked) private var panelUnlocked = false
    @AppStorage(PanelKey.on) private var panelOn = false
    @AppStorage(PanelKey.theme) private var panelTheme = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.trusted {
                Label("Automat pilnuje monitorów", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Label("Automat wyłączony: brak uprawnienia Dostępność", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Nadaj uprawnienie…") { model.requestAccess() }
            }
            // Grid: labels in one column, so both switches get the same width.
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
                        Picker("", selection: $panelOn) {
                            Text("Zwykły").tag(false)
                            Text("Panel").tag(true)
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
        }
        .font(.callout)
    }
}

struct ProfileView: View {
    @EnvironmentObject var model: Model
    let key: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title(key)).font(.title2.bold())
                    if model.differs(key) {
                        // Orange, not yellow: yellow text is unreadable on the light background.
                        Label(model.status(key), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Text(model.status(key)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if key == model.current {
                    Button("Zapisz obecny układ") { model.save() }
                    Button(model.busy ? "Przywracam…" : "Przywróć") { model.restoreNow() }
                        .disabled(model.saved[key] == nil || model.busy || !model.trusted)
                        .help(model.trusted ? "Ustaw przestrzenie jak w zapisie" : "Wymaga uprawnienia Dostępność dla tej apki")
                }
            }
            if model.saved[key] != nil {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(model.displays(key), id: \.self) { uuid in
                        MonitorView(name: model.name(uuid), tiles: model.tiles(key)[uuid] ?? [])
                    }
                }
            } else if model.saved.isEmpty {
                FirstSteps()
            } else {
                Text("Ten zestaw nie ma zapisu. Ułóż przestrzenie i kliknij „Zapisz obecny układ”.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
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
    let name: String
    let tiles: [Tile]

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if tiles.isEmpty {
                    Text("Tylko biurka").font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Array(tiles.enumerated()), id: \.offset) { i, t in
                            SpaceTile(index: i + 1, entry: t.entry, mark: t.mark)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.secondary.opacity(0.35), lineWidth: 2))
            Text(name).font(.headline)
        }
        // One tile wide at least (120 + padding): the grid wraps tiles into more rows instead, so
        // with 2–3 monitors the detail does not crowd out the sidebar.
        .frame(minWidth: 140)
    }
}

struct SpaceTile: View {
    let index: Int
    let entry: Entry
    var mark: TileMark = .none
    /// Orange caption for a tile that differs from the bar now.
    private var markText: LocalizedStringKey? {
        switch mark {
        case .none: nil
        case .unsaved: "Nie zapisane"
        case .missing where entry.isDesktop: "Brak biurka"
        case .missing: NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID).isEmpty
            ? "Nie otwarte" : "Nie na pełnym ekranie"
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
            if let markText {
                Text(markText).font(.caption2.weight(.semibold)).foregroundStyle(.orange).lineLimit(1)
            } else if let w = entry.window {
                Text(verbatim: "#\(w)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            }
        }
        .opacity(mark == .missing ? 0.55 : 1)   // a saved place with nothing behind it now
        .padding(.horizontal, 6)
        .frame(width: 120, height: 96)
        .background(RoundedRectangle(cornerRadius: 8).fill(.background))
        .overlay {
            if mark != .none { RoundedRectangle(cornerRadius: 8).strokeBorder(.orange, lineWidth: 2) }
        }
        .overlay(alignment: .topLeading) {
            Text("\(index)").font(.caption2.bold()).foregroundStyle(.secondary).padding(5)
        }
        .help(entry.title.isEmpty ? name : "\(name) — \(entry.title)")
    }
}
