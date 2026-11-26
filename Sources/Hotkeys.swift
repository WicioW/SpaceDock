import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Global shortcuts for save and restore: work from any app, set by the user in Settings, none
/// by default (a default could clash with the system or another app). Carbon's
/// RegisterEventHotKey needs no permission. Stored per action as "keyCode modifiers label".
final class Hotkeys: ObservableObject {
    enum Action: UInt32, CaseIterable { case save = 1, restore = 2, restoreOpen = 3 }

    static let shared = Hotkeys()
    static func key(_ a: Action) -> String {
        switch a {
        case .save: "hotkeySave"
        case .restore: "hotkeyRestore"
        case .restoreOpen: "hotkeyRestoreOpen"
        }
    }

    @Published var recording: Action?
    @Published var taken: Set<Action> = []   // shortcut already registered by another app
    enum Hint { case needsModifier, blocked }
    @Published var hint: Hint?               // why the key just pressed was not taken, while recording
    /// Layout shortcuts: one modifier set (stored "carbonModifiers label", e.g. "6144 ⌃⌥") plus the
    /// digit 1–9 = position of the layout in the connected set's list.
    static let layoutsKey = "hotkeyLayouts"
    @Published var recordingLayouts = false
    @Published var layoutsTaken = false      // some digit with this modifier is used by another app
    private var layoutRefs: [EventHotKeyRef] = []
    private var layoutHandler: (Int) -> Void = { _ in }
    private static let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    private var refs: [Action: EventHotKeyRef] = [:]
    private var handlers: [Action: () -> Void] = [:]
    private var monitor: Any?

    /// Called once by the app model: installs the handler and registers the stored shortcuts.
    func start(_ handlers: [Action: () -> Void], layouts: @escaping (Int) -> Void) {
        guard self.handlers.isEmpty else { return }
        self.handlers = handlers
        layoutHandler = layouts
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            if let a = Action(rawValue: id.id) { DispatchQueue.main.async { Hotkeys.shared.handlers[a]?() } }
            else if (101...109).contains(id.id) { DispatchQueue.main.async { Hotkeys.shared.layoutHandler(Int(id.id) - 100) } }
            return noErr
        }, 1, &spec, nil, nil)
        register()
    }

    private func register() {
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs = [:]
        var failed: Set<Action> = []
        for a in Action.allCases {
            guard let (code, mods, _) = Self.parse(UserDefaults.standard.string(forKey: Self.key(a)) ?? "") else { continue }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(code, mods, EventHotKeyID(signature: OSType(0x5344_4B21), id: a.rawValue),   // 'SDK!'
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs[a] = ref } else { failed.insert(a) }
        }
        taken = failed
        layoutRefs.forEach { UnregisterEventHotKey($0) }
        layoutRefs = []
        layoutsTaken = false
        guard let mods = Self.layoutModifiers()?.mods else { return }
        for (i, code) in Self.digits.enumerated() {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(code), mods, EventHotKeyID(signature: OSType(0x5344_4B21), id: UInt32(101 + i)),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { layoutRefs.append(ref) } else { layoutsTaken = true }
        }
    }

    /// The layout shortcuts' modifiers, nil when not set.
    static func layoutModifiers() -> (mods: UInt32, label: String)? {
        let parts = (UserDefaults.standard.string(forKey: layoutsKey) ?? "").split(separator: " ", maxSplits: 1)
        guard parts.count == 2, let mods = UInt32(parts[0]) else { return nil }
        return (mods, String(parts[1]))
    }

    /// "⌃⌥3" for position 3; nil past 9 or with no modifier set.
    static func layoutLabel(_ position: Int) -> String? {
        guard (1...9).contains(position), let m = layoutModifiers() else { return nil }
        return m.label + "\(position)"
    }

    /// ⌘ without ⌃ or ⌥: takes ⌘1–9 (tabs in browsers, tool windows in IntelliJ) from every app.
    static func layoutsCommandOnly() -> Bool {
        guard let m = layoutModifiers()?.mods else { return false }
        return m & UInt32(cmdKey) != 0 && m & UInt32(controlKey | optionKey) == 0
    }

    /// Records only modifiers: the set held when they are let go (or pressed with any key).
    func recordLayouts() {
        stop()
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs = [:]
        layoutRefs.forEach { UnregisterEventHotKey($0) }
        layoutRefs = []
        recordingLayouts = true
        var most: NSEvent.ModifierFlags = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] e in
            guard let self else { return e }
            let mods = e.modifierFlags.intersection([.command, .control, .option, .shift])
            if e.type == .keyDown {
                switch Int(e.keyCode) {
                case kVK_Escape: stop(); return nil
                case kVK_Delete, kVK_ForwardDelete: UserDefaults.standard.removeObject(forKey: Self.layoutsKey); stop(); return nil
                default: if !mods.isEmpty { most = mods }
                }
            } else if mods.isSuperset(of: most) {
                most = mods
                return nil
            }
            // Released (or a key pressed): take what was held, if it has ⌘, ⌃ or ⌥.
            guard !most.intersection([.command, .control, .option]).isEmpty else { most = []; return nil }
            let label = (most.contains(.control) ? "⌃" : "") + (most.contains(.option) ? "⌥" : "") + (most.contains(.shift) ? "⇧" : "") + (most.contains(.command) ? "⌘" : "")
            UserDefaults.standard.set("\(Self.carbon(most)) \(label)", forKey: Self.layoutsKey)
            stop()
            return nil
        }
    }

    /// Next key press with ⌘, ⌃ or ⌥ becomes the shortcut; Esc cancels, Delete clears it. Our own
    /// shortcuts are off meanwhile, so pressing one of them records it instead of running it.
    func record(_ a: Action) {
        stop()
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs = [:]
        recording = a
        hint = nil
        // A shortcut macOS or another app keeps for itself never reaches us: only its modifiers
        // do. Modifiers pressed and let go with no key in between = that case, so say so.
        var held = false, sawKey = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] e in
            guard let self else { return e }
            let mods = e.modifierFlags.intersection([.command, .control, .option, .shift])
            if e.type == .flagsChanged {
                if !mods.intersection([.command, .control, .option]).isEmpty {
                    if !held { held = true; sawKey = false }
                } else if mods.isEmpty, held {
                    held = false
                    if !sawKey { hint = .blocked }
                }
                return nil
            }
            sawKey = true
            switch Int(e.keyCode) {
            case kVK_Escape: break
            case kVK_Delete, kVK_ForwardDelete: clear(a); return nil
            default:
                guard !mods.intersection([.command, .control, .option]).isEmpty else { hint = .needsModifier; NSSound.beep(); return nil }
                UserDefaults.standard.set("\(e.keyCode) \(Self.carbon(mods)) \(Self.label(e, mods))", forKey: Self.key(a))
            }
            stop()
            return nil
        }
    }

    func clear(_ a: Hotkeys.Action) {
        UserDefaults.standard.removeObject(forKey: Self.key(a))
        stop()
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
        recordingLayouts = false
        hint = nil
        register()
    }

    private static func carbon(_ m: NSEvent.ModifierFlags) -> UInt32 {
        (m.contains(.command) ? UInt32(cmdKey) : 0) | (m.contains(.control) ? UInt32(controlKey) : 0)
            | (m.contains(.option) ? UInt32(optionKey) : 0) | (m.contains(.shift) ? UInt32(shiftKey) : 0)
    }

    /// The stored shortcut's label ("⌃⌥⌘S"), nil when none is set.
    static func label(_ a: Action) -> String? {
        parse(UserDefaults.standard.string(forKey: key(a)) ?? "")?.label
    }

    /// Stored shortcut "keyCode carbonModifiers label" ("1 4352 ⌃⌥⌘S"); nil when empty or broken.
    static func parse(_ stored: String) -> (code: UInt32, mods: UInt32, label: String)? {
        let parts = stored.split(separator: " ", maxSplits: 2)
        guard parts.count == 3, let code = UInt32(parts[0]), let mods = UInt32(parts[1]) else { return nil }
        return (code, mods, String(parts[2]))
    }

    private static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func label(_ e: NSEvent, _ m: NSEvent.ModifierFlags) -> String {
        (m.contains(.control) ? "⌃" : "") + (m.contains(.option) ? "⌥" : "") + (m.contains(.shift) ? "⇧" : "") + (m.contains(.command) ? "⌘" : "")
            + (keyNames[Int(e.keyCode)] ?? e.charactersIgnoringModifiers?.uppercased() ?? "?")
    }
}

/// Settings row for the layout shortcuts' modifiers ("⌃⌥" + number 1–9).
struct LayoutModifierField: View {
    @ObservedObject private var hotkeys = Hotkeys.shared
    @AppStorage(Hotkeys.layoutsKey) private var stored = ""

    var body: some View {
        HStack(spacing: 6) {
            Button {
                hotkeys.recordingLayouts ? hotkeys.stop() : hotkeys.recordLayouts()
            } label: {
                if hotkeys.recordingLayouts {
                    Text("Naciśnij modyfikatory…").frame(minWidth: 110)
                } else if let m = Hotkeys.layoutModifiers() {
                    Text(verbatim: m.label).frame(minWidth: 110)
                } else {
                    Text("Bez skrótu").foregroundStyle(.secondary).frame(minWidth: 110)
                }
            }
            .help("Kliknij, przytrzymaj modyfikatory (np. ⌃⌥) i puść. Esc: anuluj, Delete: usuń")
            Text("+ numer 1–9").foregroundStyle(.secondary)
            if !stored.isEmpty || hotkeys.recordingLayouts {
                Button { UserDefaults.standard.removeObject(forKey: Hotkeys.layoutsKey); hotkeys.stop() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Usuń skrót")
            }
        }
    }
}

/// Settings row: the shortcut, or "no shortcut"; click to record a new one.
struct ShortcutField: View {
    let action: Hotkeys.Action
    @ObservedObject private var hotkeys = Hotkeys.shared
    @AppStorage private var stored: String

    init(_ action: Hotkeys.Action) {
        self.action = action
        _stored = AppStorage(wrappedValue: "", Hotkeys.key(action))
    }

    var body: some View {
        let recording = hotkeys.recording == action
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Button {
                    recording ? hotkeys.stop() : hotkeys.record(action)
                } label: {
                    if recording {
                        Text("Naciśnij skrót…").frame(minWidth: 110)
                    } else if let label = Hotkeys.parse(stored)?.label {
                        Text(verbatim: String(label)).frame(minWidth: 110)
                    } else {
                        Text("Bez skrótu").foregroundStyle(.secondary).frame(minWidth: 110)
                    }
                }
                .help("Kliknij i naciśnij skrót z ⌘, ⌃ lub ⌥. Esc: anuluj, Delete: usuń skrót")
                if !stored.isEmpty || recording {
                    Button { hotkeys.clear(action) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Usuń skrót")
                }
            }
            // No fixedSize here: see FirstSteps (the split view's first narrow layout).
            Group {
                if recording, let hint = hotkeys.hint {
                    switch hint {
                    case .needsModifier: Text("Dodaj ⌘, ⌃ lub ⌥, sam klawisz zabrałby zwykłe pisanie.")
                    case .blocked: Text("Ten skrót nie dotarł do SpaceDock: zajmuje go macOS (np. ⌃⌘D to Słownik, ⌃⌘Q blokada ekranu) albo inna apka. Wybierz inny, np. z ⌃⌥⌘.")
                    }
                } else if recording {
                    Text("Esc: anuluj")
                } else if hotkeys.taken.contains(action) {
                    Text("Zajęty przez inną apkę, wybierz inny.")
                }
            }
            .font(.caption)
            .foregroundStyle(recording && hotkeys.hint == nil ? Color.secondary : .orange)
        }
    }
}
