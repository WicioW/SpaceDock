import SwiftUI
import AppKit

// Hidden alternative look of the window ("R", docs/design-handoff.md): black control panel with
// neon frames. Unlocked by the shuttle easter egg, fed by the same Model as the normal look.
// One monitor at a time: tiles, connection field and ribbon show the picked monitor; status,
// ratio, banner and deviation bar the whole set.

/// How strong the band sweeping down the panel is at its brightest (PanelSweep). Barely there.
let panelSweepOpacity: CGFloat = 0.1
/// How strong the still grid behind the panel is (PanelGrid): lines every 24 pt, lines every 96 pt.
let panelGridFine = 0.04, panelGridCoarse = 0.07
/// The neon glow under the big elements and the lines: a blurred copy in the element's own color,
/// a tight one and a wide one (blur in pt, strength 0…1). Three strengths: strong for the set's
/// number and mark; mid for the set's name, the connection field and the ribbon; soft for the
/// status text.
struct PanelNeon { let tight: CGFloat, tightOpacity: Double, wide: CGFloat, wideOpacity: Double }
let panelGlowStrong = PanelNeon(tight: 2.5, tightOpacity: 1, wide: 8, wideOpacity: 0.6)
let panelGlowMid = PanelNeon(tight: 2, tightOpacity: 0.8, wide: 6, wideOpacity: 0.42)
let panelGlowSoft = PanelNeon(tight: 1.6, tightOpacity: 0.6, wide: 5, wideOpacity: 0.28)
/// How dark the horizontal lines on every filled field are (PanelScanned).
let panelScanOpacity = 0.1

enum PanelKey {
    static let unlocked = "panelUnlocked", on = "panelOn", theme = "panelTheme"
}

struct PanelTheme {
    let s, k, t, e, w: Color   // frames/save, match/now, captions, error, excess

    static func number(_ n: Int) -> PanelTheme {
        let hex = { (v: UInt32) in Color(red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255) }
        switch n {
        case 2: return PanelTheme(s: hex(0xFF3FB4), k: hex(0x3FF0FF), t: hex(0xD6F7FF), e: hex(0xFF4A1C), w: hex(0xFFD60A))
        case 3: return PanelTheme(s: hex(0xFF2A2A), k: hex(0x5CF0B0), t: hex(0xFF8A1E), e: hex(0xFFFFFF), w: hex(0x4DA6FF))   // excess blue: yellow sat too close to the orange captions
        default: return PanelTheme(s: hex(0x9B6CFF), k: hex(0xB4FF39), t: hex(0xD9C9FF), e: hex(0xFF3B30), w: hex(0xFFD60A))
        }
    }
}

/// The design's fonts: Orbitron (numbers), Chakra Petch (labels), JetBrains Mono (data), shipped
/// in the app's Resources/Fonts (assets/fonts, OFL) and registered for this process only, nothing
/// is installed on the Mac. Outside the bundle (swift run) or if that fails: system fonts.
enum PanelFont {
    private static let shipped: Bool = {
        let files = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in files { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        return !files.isEmpty
    }()
    private static func has(_ family: String) -> Bool { _ = shipped; return NSFontManager.shared.availableFontFamilies.contains(family) }
    private static let orbitron = has("Orbitron"), chakra = has("Chakra Petch"), jetbrains = has("JetBrains Mono")

    // By face name: asking a family for a weight does not always pick the right face
    // (Orbitron's "black" came back as ExtraBold).
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        orbitron ? .custom(weight == .bold ? "Orbitron-Bold" : "Orbitron-Black", fixedSize: size) : .system(size: size, weight: weight).width(.expanded)
    }
    static func ui(_ size: CGFloat = 13, _ weight: Font.Weight = .semibold) -> Font {
        chakra ? .custom(weight == .bold ? "ChakraPetch-Bold" : weight == .medium ? "ChakraPetch-Medium" : "ChakraPetch-SemiBold", fixedSize: size)
            : .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat = 11, _ weight: Font.Weight = .regular) -> Font {
        jetbrains ? .custom(weight == .medium ? "JetBrainsMono-Medium" : "JetBrainsMono-Regular", fixedSize: size)
            : .system(size: size, weight: weight, design: .monospaced)
    }
    static func kanji(_ size: CGFloat) -> Font { .custom("Hiragino Mincho ProN", fixedSize: size).weight(.heavy) }
    /// A big mark: two Japanese characters, or in Chinese an English word in the numbers' font,
    /// small enough for the same two-character field (it still shrinks to fit).
    static func mark(_ size: CGFloat) -> Font { panelChinese ? display(size * 0.42, .black) : kanji(size) }
    static func nsUI(_ size: CGFloat) -> NSFont {   // bold, for text drawn on a layer
        (chakra ? NSFont(name: "ChakraPetch-Bold", size: size) : nil) ?? .systemFont(ofSize: size, weight: .bold)
    }
    static func nsMono(_ size: CGFloat) -> NSFont {
        (jetbrains ? NSFont(name: "JetBrainsMono-Regular", size: size) : nil) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
    static func outline(_ size: CGFloat) -> NSFont {
        (orbitron ? NSFont(name: "Orbitron-Black", size: size) : nil) ?? .systemFont(ofSize: size, weight: .black)
    }
}

/// Localized like the rest of the app (the Polish text is the key), in the panel's capitals.
private func U(_ key: String.LocalizationValue) -> String { String(localized: key).uppercased() }

private func frac(_ x: Double) -> Double { x - x.rounded(.down) }

/// The panel's Japanese marks are decoration next to the label in the app's language. In Chinese
/// the label is already the same characters, so an English word stands there instead.
private let panelChinese = Bundle.main.preferredLocalizations.first?.hasPrefix("zh") ?? false
private let panelMarks = ["配置": "LAYOUT", "接続中": "ONLINE", "保存": "SAVE", "復元": "RESTORE", "相違": "DIFF", "一致": "MATCH",
                          "未保存": "UNSAVED", "未起動": "NOT OPEN", "画面": "SCREEN", "一致率": "RATIO", "手動": "MANUAL", "自動": "AUTO",
                          "設定": "SETTINGS", "方式": "METHOD", "言語": "LANGUAGE", "起動": "LOGIN", "監視": "WATCH", "偏差": "DEVIATION"]
private func J(_ mark: String) -> String { panelChinese ? panelMarks[mark] ?? mark : mark }

// MARK: - Data

/// `moved`: saved and on the bar, but at another place among the saved Spaces than in the save.
enum SpaceState { case ok, moved, unsaved, missing, noFullScreen }

struct PanelTile {
    let index: Int
    let num: String          // place in the save, "+" for a Space not saved
    let entry: Entry
    var state: SpaceState
    var now = 0              // place on the bar now, for a moved Space
    var space: Int? = nil    // the Space on the bar now (connected set), to go to it

    var isError: Bool { state == .missing || state == .noFullScreen }
    var app: String { (entry.isDesktop ? String(localized: "Biurko") : entry.app).uppercased() }
    var word: String {
        switch state {
        case .ok: U("Zgodny")
        case .moved: U("Przestawione") + " › \(now)"
        case .unsaved: U("Nie zapisane")
        case .missing: entry.isDesktop ? U("Brak biurka") : U("Nie otwarte")
        case .noFullScreen: U("Nie na pełnym ekranie")
        }
    }
    var short: String {
        switch state {
        case .ok: ""
        case .moved: U("Przestawione") + " › \(now)"
        case .unsaved: U("Nowa") + (" " + J("未保存"))
        case .missing: U("Brak") + (" " + J("未起動"))
        case .noFullScreen: U("Okno") + (" " + J("相違"))
        }
    }
    var kanji: String {
        switch state {
        case .ok: J("一致")
        case .unsaved: J("未保存")
        case .missing: J("未起動")
        case .moved, .noFullScreen: J("相違")
        }
    }
    func color(_ th: PanelTheme) -> Color { state == .ok ? th.t : isError ? th.e : th.w }
    /// The color of the Space's state, for the rings around whatever stands for it under the pointer.
    func ring(_ th: PanelTheme) -> Color { state == .ok ? th.k : color(th) }
}

struct PanelCell {
    let label: String
    let state: SpaceState
}

struct PanelMonitor {
    let uuid: String
    let name: String
    let tiles: [PanelTile]
    let top: [PanelCell]        // Spaces in saved order
    let bottom: [PanelCell]     // Spaces on the bar now
    let links: [(Int, Int)]     // top index → bottom index, the same Space

    var diffs: Int { tiles.filter { $0.state != .ok }.count }
    var hasError: Bool { tiles.contains { $0.isError } }

    // The same Space as a tile and as cells of the connection field (a tile's index = its place in `tiles`).
    // ponytail: the k-th tile "not saved" is taken for the k-th "+" cell of the now row; carry the
    // Space ID in both if they ever come in different orders.
    private var savedTiles: [Int] { tiles.indices.filter { tiles[$0].state != .unsaved } }
    private var newTiles: [Int] { tiles.indices.filter { tiles[$0].state == .unsaved } }
    private var newCells: [Int] { bottom.indices.filter { bottom[$0].state == .unsaved } }

    func cells(of tile: Int) -> (top: Int?, bottom: Int?) {
        if let i = savedTiles.firstIndex(of: tile) { return (i, links.first { $0.0 == i }?.1) }
        guard let k = newTiles.firstIndex(of: tile), k < newCells.count else { return (nil, nil) }
        return (nil, newCells[k])
    }
    func tile(top i: Int) -> Int? { savedTiles.indices.contains(i) ? savedTiles[i] : nil }
    func tile(bottom j: Int) -> Int? {
        if let i = links.first(where: { $0.1 == j })?.0 { return tile(top: i) }
        guard let k = newCells.firstIndex(of: j), k < newTiles.count else { return nil }
        return newTiles[k]
    }
    var differs: Bool { diffs > 0 }
}

struct PanelStatus {
    let color: Color
    let top, kanji, word, sub: String
    let active: Bool   // blinks, tapes run
}

/// `links`: (place in the save, place on the bar) of each saved Space on the bar, in save order.
/// Returns (place in the save, place on the bar from 1) of every one whose rank among them differs.
func outOfOrder(_ links: [(Int, Int)]) -> [(Int, Int)] {
    let places = links.map(\.1).sorted()
    return links.enumerated().compactMap { k, l in places[k] != l.1 ? (l.0, l.1 + 1) : nil }
}

struct PanelData {
    let key: String
    let connected: Bool
    let hasSave: Bool
    let monitors: [PanelMonitor]

    init(_ model: Model, key: String) {
        self.key = key
        let connected = key == model.current
        self.connected = connected
        let layout = model.saved[key]
        hasSave = layout != nil
        // A connected set with no save yet: everything on the bars shows as "not saved".
        let tiles: [String: [Tile]] = connected
            ? layoutDiff(saved: layout ?? [:], live: model.liveSpaces, describe: model.describe)
            : (layout ?? [:]).mapValues { $0.map { Tile(entry: $0, mark: .none) } }
        let pick = connected ? matchSpaces(current: model.liveSpaces, saved: layout ?? [:]).pick : [:]
        monitors = model.displays(key).map { d in
            var n = 0
            var ts: [PanelTile] = (tiles[d] ?? []).enumerated().map { i, t in
                let state: SpaceState = switch t.mark {
                case .none: .ok
                case .unsaved: .unsaved
                case .missing: t.entry.isDesktop || NSRunningApplication.runningApplications(withBundleIdentifier: t.entry.bundleID).isEmpty
                    ? .missing : .noFullScreen
                }
                if state != .unsaved { n += 1 }
                return PanelTile(index: i, num: state == .unsaved ? "+" : String(format: "%02d", n), entry: t.entry, state: state, space: t.space)
            }
            let saved = ts.indices.filter { ts[$0].state != .unsaved }   // tiles in the save: index here = place in the save
            var bottom: [PanelCell] = [], links: [(Int, Int)] = []
            if connected {
                let live = model.liveSpaces[d] ?? []
                let place = Dictionary(uniqueKeysWithValues: (pick[d] ?? [:]).map { ($0.value, $0.key) })   // Space ID → saved index
                // ponytail: a Space here that the save keeps on another monitor shows as "+";
                // give it its own mark if moving Spaces between monitors by hand becomes common.
                bottom = live.map { s in
                    place[s.id].map { PanelCell(label: String(format: "%02d", $0 + 1), state: .ok) } ?? PanelCell(label: "+", state: .unsaved)
                }
                links = saved.indices.compactMap { i in
                    guard let id = pick[d]?[i], let j = live.firstIndex(where: { $0.id == id }) else { return nil }
                    return (i, j)
                }
                // Out of order: every Space whose place among the saved ones on the bar is not its
                // place in the save (two swapped Spaces are both marked). Missing and unsaved
                // Spaces do not count, so they shift nobody's place.
                for (i, now) in outOfOrder(links) {
                    ts[saved[i]].state = .moved
                    ts[saved[i]].now = now
                }
            }
            return PanelMonitor(uuid: d, name: model.name(d).uppercased(), tiles: ts,
                                top: saved.map { PanelCell(label: ts[$0].num, state: ts[$0].state) },
                                bottom: bottom, links: links)
        }
    }

    var tiles: [PanelTile] { monitors.flatMap(\.tiles) }
    var diffs: Int { monitors.map(\.diffs).reduce(0, +) }
    var savedCount: Int { tiles.filter { $0.state != .unsaved }.count }
    var okCount: Int { tiles.filter { $0.state == .ok }.count }
    var hasError: Bool { monitors.contains { $0.hasError } }
    var hasUnsaved: Bool { tiles.contains { $0.state == .unsaved } }
    var differs: Bool { monitors.contains { $0.differs } }
    /// First monitor with a difference, else the first one.
    var defaultMonitor: Int { monitors.firstIndex { $0.differs } ?? 0 }
    var deviation: String { diffs > 0 ? U("\(diffs) różn.") : "0" }

    func status(_ th: PanelTheme, busy: Bool) -> PanelStatus {
        if connected && busy {
            return PanelStatus(color: th.s, top: U("Procedura"), kanji: J("復元"), word: U("Przywracam…").replacingOccurrences(of: "…", with: ""),
                               sub: U("Układam przestrzenie…"), active: true)
        }
        if !hasSave {
            return PanelStatus(color: th.w, top: U("Uwaga"), kanji: J("未保存"), word: U("Brak zapisu"),
                               sub: connected ? U("Podłączony, brak zapisu") : U("Niepodłączony"), active: connected)
        }
        if !connected {
            return PanelStatus(color: th.s, top: U("Stan"), kanji: J("保存"), word: U("Zapis"), sub: U("Niepodłączony"), active: false)
        }
        if differs {
            return PanelStatus(color: hasError ? th.e : th.w, top: U("Uwaga"), kanji: J("相違"), word: U("Różnica"),
                               sub: U("Układ inny niż zapis"), active: true)
        }
        return PanelStatus(color: th.k, top: U("Stan"), kanji: J("一致"), word: U("Zgodny"), sub: U("Układ zgodny z zapisem"), active: false)
    }
}

/// What the panel remembers while it is open (no @State: see Model.columns).
final class PanelState: ObservableObject {
    @Published var monitorPick: [String: String] = [:]   // set key → monitor UUID chosen by hand
    /// The Space under the pointer (tile index on the picked monitor), shared by its tile, its
    /// cells in the connection field, the detail bar and its label on the ribbon.
    /// `-panelShotHover n` sets it for `panel-shot`, where there is no pointer.
    @Published var hover: Int? = UserDefaults.standard.object(forKey: "panelShotHover") == nil ? nil : UserDefaults.standard.integer(forKey: "panelShotHover")
    private var fieldHover: Int?   // what the connection field pointed at last
    @Published var armed = false                         // save cover lifted
    @Published var boot = 0.0                            // seconds since the window opened, in steps
    @Published var logTail: [String] = []
    @Published var onScreen = true                       // motion stops while the window is covered or the app inactive
    private var timers: [Timer] = []
    private var armCount = 0
    private var watching: [NSObjectProtocol] = []

    /// Leaving puts the highlight out only if it still shows the Space that was left.
    func point(_ tile: Int, _ inside: Bool) {
        if inside { if hover != tile { hover = tile } } else if hover == tile { hover = nil }
    }

    /// The connection field reports the Space under the pointer on every move, nil for none.
    func pointField(_ tile: Int?) {
        guard tile != fieldHover else { return }
        if let was = fieldHover { point(was, false) }
        fieldHover = tile
        if let tile { point(tile, true) }
    }

    init() {
        // A minimized or fully covered window is not `.visible` either.
        for name in [NSWindow.didChangeOcclusionStateNotification, NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            watching.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                let shown = NSApp.isActive && NSApp.windows.contains { $0.occlusionState.contains(.visible) }
                if self?.onScreen != shown { self?.onScreen = shown }
            })
        }
        readLog()
        timers.append(.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.readLog() })
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { boot = 2; return }
        timers.append(.scheduledTimer(withTimeInterval: 0.075, repeats: true) { [weak self] t in
            guard let self, self.boot < 1.1 else { t.invalidate(); return }
            self.boot += 0.075
        })
    }

    deinit {
        timers.forEach { $0.invalidate() }
        watching.forEach(NotificationCenter.default.removeObserver)
    }

    /// First click lifts the cover; it drops back by itself after 5 s.
    func arm() {
        armed = true
        armCount += 1
        let mine = armCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.armCount == mine { self?.armed = false }
        }
    }

    /// Last lines of the app's log: what the last restore really did.
    private func readLog() {
        guard let h = try? FileHandle(forReadingFrom: logFile) else { return }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        try? h.seek(toOffset: size > 1500 ? size - 1500 : 0)
        let text = String(decoding: (try? h.readToEnd()) ?? Data(), as: UTF8.self)
        let lines = Array(text.split(separator: "\n").suffix(3).map { $0.uppercased() })
        if lines != logTail { logTail = lines }
    }
}

// MARK: - Motion pieces

/// No motion: the system's Reduce Motion, the window covered or minimized, or the app not active.
private struct PanelStillKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var panelStill: Bool {
        get { self[PanelStillKey.self] }
        set { self[PanelStillKey.self] = newValue }
    }
}

// Smooth motion runs on Core Animation layers: a layer is drawn once and gets one looping
// animation, so the render server moves it at the display's rate and the app does nothing per
// frame. (A SwiftUI Canvas redrawn per step cost ~20 ms of CPU each time, and TimelineView's
// `.animation` schedule redraws the window at the display's rate whatever its interval.)

/// A view made of plain layers. `build` fills the root layer for a size (origin top left); it
/// runs again when `key` or the size changes.
struct PanelLayers: NSViewRepresentable {
    let key: String
    let build: (CALayer, CGSize) -> Void

    func makeNSView(context: Context) -> PanelLayerHost { PanelLayerHost() }

    func updateNSView(_ view: PanelLayerHost, context: Context) {
        view.key = key
        view.build = build
        view.needsLayout = true
    }
}

final class PanelLayerHost: NSView {
    var key = ""
    var build: (CALayer, CGSize) -> Void = { _, _ in }
    private var built = ""

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("not in a nib") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // clicks belong to the SwiftUI views around
    override func viewDidMoveToWindow() { built = ""; needsLayout = true }

    override func layout() {
        super.layout()
        let stamp = "\(key)|\(bounds.size)"
        guard let layer, let window, stamp != built, bounds.width > 0, bounds.height > 0 else { return }
        built = stamp
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.sublayers = nil
        build(layer, bounds.size)
        func sharpen(_ l: CALayer) {
            l.contentsScale = window.backingScaleFactor
            l.rasterizationScale = window.backingScaleFactor
            l.sublayers?.forEach(sharpen)
        }
        sharpen(layer)
        CATransaction.commit()
    }
}

/// A shape drawn once: kept as a bitmap, so moving or scaling it costs the window server no
/// new drawing (a bare CAShapeLayer is drawn again in every frame while anything animates).
private func panelShape(_ path: Path, stroke: Color? = nil, fill: Color? = nil, width: CGFloat = 1, dash: [NSNumber]? = nil) -> CAShapeLayer {
    let l = CAShapeLayer()
    let box = path.boundingRect.insetBy(dx: -width - 1, dy: -width - 1).integral
    l.frame = box
    l.path = path.offsetBy(dx: -box.minX, dy: -box.minY).cgPath
    l.shouldRasterize = true
    l.strokeColor = stroke.map { NSColor($0).cgColor }
    l.fillColor = fill.map { NSColor($0).cgColor }
    l.lineWidth = width
    l.lineDashPattern = dash
    return l
}

/// Frames per second of the smooth motion; 0 = the display's own rate. The app itself does no
/// work per frame, but the window server composes the whole window for each one. Measured for
/// the panel in a 1450 × 749 window on a 120 Hz display, in percent of one core added to
/// WindowServer: 120 fps +29, 60 fps +23, 30 fps +10, 20 fps +8.
let panelFrameRate: Float = 30

/// One value running from `from` to `to`, over and over.
private func panelLoop(_ keyPath: String, from: CGFloat, to: CGFloat, _ duration: Double) -> CABasicAnimation {
    let a = CABasicAnimation(keyPath: keyPath)
    a.fromValue = from
    a.toValue = to
    a.duration = duration
    a.repeatCount = .infinity
    if panelFrameRate > 0 { a.preferredFrameRateRange = CAFrameRateRange(minimum: panelFrameRate, maximum: panelFrameRate, preferred: panelFrameRate) }
    return a
}

/// Values held one after another (no easing between them), over and over.
private func panelSteps(_ keyPath: String, _ values: [CGFloat], every: Double, offset: Double = 0) -> CAKeyframeAnimation {
    let a = CAKeyframeAnimation(keyPath: keyPath)
    a.values = values
    a.calculationMode = .discrete
    a.duration = every * Double(values.count)
    a.timeOffset = offset
    a.repeatCount = .infinity
    return a
}

// MARK: - Glow

extension View {
    /// The glow for a still view (number, mark, name, status text): drawn again only with the view.
    func panelGlow(_ color: Color, _ neon: PanelNeon) -> some View {
        shadow(color: color.opacity(neon.tightOpacity), radius: neon.tight).shadow(color: color.opacity(neon.wideOpacity), radius: neon.wide)
    }
}

/// A Canvas context in which whatever is drawn glows in `color`.
func panelGlowing(_ context: GraphicsContext, _ color: Color, _ neon: PanelNeon = panelGlowMid) -> GraphicsContext {
    var glowing = context
    glowing.addFilter(.shadow(color: color.opacity(neon.wideOpacity), radius: neon.wide))
    glowing.addFilter(.shadow(color: color.opacity(neon.tightOpacity), radius: neon.tight))
    return glowing
}

/// The glow of a shape (`outline`: its filled area; for a line, its stroked path) as a layer to
/// put under the shape itself: shadows only, drawn once and kept as a bitmap, so a line that
/// moves over it (running dashes, a pulse) costs nothing more.
private func panelGlowLayer(_ outline: Path, color: Color, _ neon: PanelNeon = panelGlowMid) -> CALayer {
    let holder = CALayer()
    let box = outline.boundingRect.insetBy(dx: -3 * neon.wide, dy: -3 * neon.wide).integral
    guard !box.isNull, !box.isInfinite else { return holder }
    holder.frame = box
    let path = outline.offsetBy(dx: -box.minX, dy: -box.minY).cgPath
    for (radius, opacity) in [(neon.tight, neon.tightOpacity), (neon.wide, neon.wideOpacity)] {
        let shadow = CALayer()
        shadow.frame = holder.bounds
        shadow.shadowPath = path
        shadow.shadowColor = NSColor(color).cgColor
        shadow.shadowOffset = .zero
        shadow.shadowRadius = radius
        shadow.shadowOpacity = Float(opacity)
        holder.addSublayer(shadow)
    }
    // The shadow of a path also fills the path itself; the shape drawn over it covers that.
    holder.shouldRasterize = true
    return holder
}

// MARK: - Hover

private final class PanelHoverFlag: ObservableObject { @Published var on = false }

/// Everything clickable under the pointer: `content` gets `hot` and draws itself inverted (filled
/// with its own color, text black), as a table row in a terminal does. 0.075 s, linear.
private struct PanelHot<Content: View>: View {
    var enabled = true
    @ViewBuilder let content: (Bool) -> Content
    @StateObject private var flag = PanelHoverFlag()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hot = flag.on && enabled
        content(hot).onHover { flag.on = $0 }.animation(reduceMotion ? nil : .linear(duration: 0.075), value: hot)
    }
}

/// The set under the pointer, shared by its hexagon in the header and its row in the rail, so
/// both light up together.
private final class PanelSetHover: ObservableObject {
    static let shared = PanelSetHover()
    @Published var key: AnyHashable?
}

/// `PanelHot` for a set's hexagon and row: hot when the pointer is over either of the two.
private struct PanelSetHot<Content: View>: View {
    let key: AnyHashable
    @ViewBuilder let content: (Bool) -> Content
    @ObservedObject private var hover = PanelSetHover.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hot = hover.key == key
        content(hot)
            .onHover { inside in
                if inside { hover.key = key } else if hover.key == key { hover.key = nil }   // leaving must not put out the next one
            }
            .animation(reduceMotion ? nil : .linear(duration: 0.075), value: hot)
    }
}

/// An element that is filled already cannot invert: under the pointer it gets lighter instead.
private struct PanelGlow<S: Shape>: View {
    let on: Bool
    var shape: S

    var body: some View { shape.fill(Color.white.opacity(on ? 0.15 : 0)).allowsHitTesting(false) }
}

/// The panel's fill, used for everything filled with a theme color: the color with still
/// horizontal lines over it, under the text: 2 pt clean, 2 pt darkened, counted from the fill's
/// top edge. Black lines, so any role color in any theme works, and on black they do not show:
/// an element that is filled only when picked or under the pointer can keep this as its background.
struct PanelScanned: View {
    let color: Color

    /// The lines as a tile drawn once (2 × 8 px = 1 × 4 pt), repeated by the system.
    private static let lines: Image = {
        let context = CGContext(data: nil, width: 2, height: 8, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 0, alpha: panelScanOpacity))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 4))   // the lower half: Core Graphics counts from the bottom
        return Image(decorative: context.makeImage()!, scale: 2)
    }()

    var body: some View { color.overlay(Rectangle().fill(ImagePaint(image: Self.lines))) }
}

/// The same lines inside a Canvas, over a rectangle already filled with a color.
/// `top`: where the lines are counted from, for plates stacked into one fill.
func panelScan(_ context: inout GraphicsContext, _ rect: CGRect, top: CGFloat? = nil) {
    var lines = Path()
    for y in stride(from: (top ?? rect.minY) + 2, to: rect.maxY, by: 4) where y >= rect.minY {
        lines.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: min(2, rect.maxY - y)))
    }
    context.fill(lines, with: .color(.black.opacity(panelScanOpacity)))
}

/// Still grid in the frame color on the panel's bare black, under everything: 1 pt lines every
/// 24 pt and stronger ones every 96 pt. Drawn again only when the size or the theme changes.
struct PanelGrid: View {
    let th: PanelTheme

    var body: some View {
        Canvas { context, size in
            var fine = Path(), coarse = Path()
            for x in stride(from: 0, to: size.width, by: 24) {
                if Int(x) % 96 == 0 { coarse.addRect(CGRect(x: x, y: 0, width: 1, height: size.height)) } else { fine.addRect(CGRect(x: x, y: 0, width: 1, height: size.height)) }
            }
            for y in stride(from: 0, to: size.height, by: 24) {
                if Int(y) % 96 == 0 { coarse.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)) } else { fine.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)) }
            }
            context.fill(fine, with: .color(th.s.opacity(panelGridFine)))
            context.fill(coarse, with: .color(th.s.opacity(panelGridCoarse)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One soft band in the frame color going down the whole panel under the title row, 180 pt/s,
/// over and over; it only lightens what is under it. Not there at all without motion.
struct PanelSweep: View {
    let th: PanelTheme
    @Environment(\.panelStill) private var still

    var body: some View {
        PanelLayers(key: "\(th.s)|\(still)") { layer, size in
            guard !still else { return }
            layer.masksToBounds = true
            let band = CAGradientLayer()
            let color = NSColor(th.s)
            band.colors = [color.withAlphaComponent(0).cgColor, color.withAlphaComponent(panelSweepOpacity).cgColor, color.withAlphaComponent(0).cgColor]
            band.locations = [0, 0.44, 1]
            band.frame = CGRect(x: 0, y: -96, width: size.width, height: 96)
            band.compositingFilter = "screenBlendMode"   // ponytail: plain blending where the filter is not applied; at 10% the difference is small
            band.add(panelLoop("position.y", from: -48, to: size.height + 48, (size.height + 96) / 180), forKey: "sweep")
            layer.addSublayer(band)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Diagonal warning stripes, sliding when `moving`.
struct PanelTape: View {
    let color: Color
    var stripe: CGFloat = 10
    var period = 0.5
    var moving = true
    var reverse = false
    @Environment(\.panelStill) private var still

    var body: some View {
        let run = moving && !still
        PanelLayers(key: "\(color)|\(stripe)|\(period)|\(run)|\(reverse)") { layer, size in
            let w = stripe * 2.0.squareRoot()
            let stripes = panelShape(PanelStripes(w: w).path(in: CGRect(origin: .zero, size: size)), fill: color)
            layer.addSublayer(stripes)
            if run { stripes.add(panelLoop("transform.translation.x", from: reverse ? 2 * w : 0, to: reverse ? 0 : 2 * w, period), forKey: "run") }
        }
        .allowsHitTesting(false)
    }
}

/// Running stripes for a tile's bar. The bar is tilted by SwiftUI, which an NSView does not
/// follow, so this view is `rise` taller than the bar (upward) and cuts the tilted bar out itself.
struct PanelHatch: View {
    static let rise: CGFloat = 26, tilt: CGFloat = 0.0875   // 5°; the rise covers bars up to ~290 pt wide
    let color: Color
    @Environment(\.panelStill) private var still

    var body: some View {
        PanelLayers(key: "\(color)|\(still)") { layer, size in
            let w = 5 * 2.0.squareRoot(), drop = size.width * Self.tilt
            let stripes = panelShape(PanelStripes(w: w).path(in: CGRect(origin: .zero, size: size)), fill: color)
            let bar = CAShapeLayer()
            bar.path = Path { p in
                p.addLines([CGPoint(x: 0, y: Self.rise), CGPoint(x: size.width, y: Self.rise - drop),
                            CGPoint(x: size.width, y: size.height - drop), CGPoint(x: 0, y: size.height)])
                p.closeSubpath()
            }.cgPath
            let box = CALayer()
            box.frame = CGRect(origin: .zero, size: size)
            box.mask = bar
            box.addSublayer(stripes)
            layer.addSublayer(box)
            if !still { stripes.add(panelLoop("transform.translation.x", from: 0, to: 2 * w, 0.7), forKey: "run") }
        }
        .allowsHitTesting(false)
    }
}

/// Stripes leaning right, from two periods before the frame's left edge.
struct PanelStripes: Shape {
    let w: CGFloat

    func path(in r: CGRect) -> Path {
        var path = Path(), x = -r.height - 4 * w
        while x < r.width {
            path.addLines([CGPoint(x: x, y: r.height), CGPoint(x: x + w, y: r.height), CGPoint(x: x + w + r.height, y: 0), CGPoint(x: x + r.height, y: 0)])
            path.closeSubpath()
            x += 2 * w
        }
        return path
    }
}

/// What jumps by design and is drawn by SwiftUI keeps a clock in the app, one that wakes only at
/// the two moments in every 1.2 s when a blinking light changes.
struct PanelBlinkClock: TimelineSchedule {
    func entries(from start: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var t = (start.timeIntervalSinceReferenceDate / 1.2).rounded(.down) * 1.2, dim = false
        return AnyIterator {
            defer { t += dim ? 0.54 : 0.66; dim.toggle() }
            return Date(timeIntervalSinceReferenceDate: t)
        }
    }
}

/// Hard blink every 1.2 s, like the status bar.
struct PanelBlink: ViewModifier {
    let on: Bool
    @Environment(\.panelStill) private var reduceMotion

    func body(content: Content) -> some View {
        if on && !reduceMotion {
            TimelineView(PanelBlinkClock()) { timeline in
                content.opacity(frac((timeline.date.timeIntervalSinceReferenceDate + 0.01) / 1.2) < 0.55 ? 1 : 0.4)
            }
        } else {
            content
        }
    }
}

extension View {
    func panelBlink(_ on: Bool) -> some View { modifier(PanelBlink(on: on)) }

    /// Zone revealed from the left when the window opens: 0.6 s in 8 steps.
    @ViewBuilder func panelBoot(_ boot: Double, delay: Double) -> some View {
        let p = min(1, max(0, ((boot - delay) / 0.6 * 8).rounded(.down) / 8))
        // The mask goes once the zone is open: a masked zone is drawn off screen whenever it changes.
        if p < 1 { mask(Rectangle().padding(-30).scaleEffect(x: p, anchor: .leading)) } else { self }
    }
}

private func glyphPath(_ text: String, font: NSFont) -> Path {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
    var path = Path()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n), at = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(), &glyphs)
        CTRunGetPositions(run, CFRange(), &at)
        for i in 0..<n {
            guard let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
            path.addPath(Path(g), transform: CGAffineTransform(translationX: at[i].x, y: at[i].y))
        }
    }
    return path.applying(CGAffineTransform(scaleX: 1, y: -1))   // baseline at y = 0, glyphs above it
}

// MARK: - Window

struct PanelView: View {
    @EnvironmentObject var model: Model
    @StateObject private var state = PanelState()
    @AppStorage(PanelKey.theme) private var themeNumber = 1
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        // Designed at 1100 × 700: a bigger window gives the room to the monitor zone, a smaller
        // one (down to the app's 780 × 420) scales the whole panel down.
        GeometryReader { geo in
            let scale = min(1, geo.size.width / 1100, geo.size.height / 700)
            content(scale)
                .frame(width: geo.size.width / scale, height: geo.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Color.black)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 780, minHeight: 420)
    }

    private func content(_ scale: CGFloat) -> some View {
        let th = PanelTheme.number(themeNumber)
        let key = model.selection ?? model.current
        let data = PanelData(model, key: key)
        let status = data.status(th, busy: model.busy)
        let picked = state.monitorPick[key].flatMap { u in data.monitors.firstIndex { $0.uuid == u } } ?? data.defaultMonitor
        let monitor = data.monitors.indices.contains(picked) ? data.monitors[picked] : nil
        return VStack(spacing: 0) {
            ZStack {
                HStack {
                    Text(verbatim: "SPACEDOCK").font(PanelFont.display(12)).tracking(3).foregroundStyle(th.t)
                    Spacer()
                }
                .padding(.leading, 82 / scale)   // the window buttons do not scale
                PanelShuttle(th: th)
            }
            .frame(height: 30)
            .overlay(alignment: .bottom) { th.s.frame(height: 1) }
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    PanelHeader(th: th, data: data, status: status)
                        .frame(height: 96)
                        .panelBoot(state.boot, delay: 0)
                    PanelZone(th: th, data: data, picked: picked, state: state)
                        .frame(maxHeight: .infinity)
                        .panelBoot(state.boot, delay: 0.2)
                    PanelBanner(th: th, status: status)
                    PanelRibbonBlock(th: th, data: data, tiles: monitor?.tiles ?? [], hover: state.hover)
                        .panelBoot(state.boot, delay: 0.4)
                }
                PanelRail(th: th, data: data, state: state)
                    .frame(width: 264)
                    .panelBoot(state.boot, delay: 0.3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PanelGrid(th: th))
            .overlay(PanelSweep(th: th))
        }
        .foregroundStyle(th.t)
        .font(PanelFont.ui())
        .environment(\.panelStill, systemReduceMotion || !state.onScreen)
    }
}

/// The shuttle in outline. Same 10 quick clicks as the normal look: here they switch back to it.
struct PanelShuttle: View {
    let th: PanelTheme
    @StateObject private var egg = ShuttleEggState()

    var body: some View {
        Button {
            egg.tap { UserDefaults.standard.set(false, forKey: PanelKey.on) }
        } label: {
            Canvas { context, _ in
                var hull = Path()
                hull.addLines([CGPoint(x: 26, y: 7), CGPoint(x: 18, y: 4.5), CGPoint(x: 9, y: 0.5), CGPoint(x: 6, y: 0.5), CGPoint(x: 6, y: 7)])
                hull.addLines([CGPoint(x: 26, y: 13), CGPoint(x: 18, y: 15.5), CGPoint(x: 9, y: 19.5), CGPoint(x: 6, y: 19.5), CGPoint(x: 6, y: 13)])
                hull.move(to: CGPoint(x: 4, y: 7))
                hull.addLine(to: CGPoint(x: 34, y: 7))
                hull.addCurve(to: CGPoint(x: 44, y: 10), control1: CGPoint(x: 40, y: 7), control2: CGPoint(x: 43, y: 9))
                hull.addCurve(to: CGPoint(x: 34, y: 13), control1: CGPoint(x: 43, y: 11), control2: CGPoint(x: 40, y: 13))
                hull.addLine(to: CGPoint(x: 4, y: 13))
                hull.closeSubpath()
                context.stroke(hull, with: .color(egg.lit ? .white : th.k), lineWidth: 1)
                context.stroke(Path(CGRect(x: 12, y: 8.4, width: 18, height: 3.2)), with: .color(th.s), lineWidth: 1)
                for x in [50, 62, 74] as [CGFloat] {
                    context.stroke(Path(CGRect(x: x, y: 6.5, width: 8, height: 7)), with: .color(th.t), lineWidth: 1)
                }
            }
            .frame(width: 86, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(ShuttlePress(egg: egg))
        .accessibilityHidden(true)   // decoration; the look also switches in Settings
    }
}

// MARK: - Header

struct PanelHex: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.addLines([CGPoint(x: r.minX + r.width * 0.25, y: r.minY), CGPoint(x: r.minX + r.width * 0.75, y: r.minY),
                        CGPoint(x: r.maxX, y: r.midY), CGPoint(x: r.minX + r.width * 0.75, y: r.maxY),
                        CGPoint(x: r.minX + r.width * 0.25, y: r.maxY), CGPoint(x: r.minX, y: r.midY)])
            p.closeSubpath()
        }
    }
}

struct PanelHeader: View {
    @EnvironmentObject var model: Model
    let th: PanelTheme
    let data: PanelData
    let status: PanelStatus

    private var number: String {
        model.profiles.firstIndex(of: data.key).map { String(format: "%02d", $0 + 1) } ?? "--"
    }

    var body: some View {
        let name = model.title(data.key).uppercased()
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, _ in
                    context.translateBy(x: 2, y: 66)
                    context.stroke(glyphPath(number, font: PanelFont.outline(76)), with: .color(th.s), lineWidth: 2)
                }
                .frame(height: 76)
                .panelGlow(th.s, panelGlowStrong)
                PanelTape(color: th.s, moving: status.active).frame(height: 12)
            }
            .frame(width: 130)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Text(verbatim: J("配置")).font(PanelFont.mark(40)).foregroundStyle(th.s)
                        .lineLimit(1).minimumScaleFactor(0.5).frame(width: 80, height: 42)
                        .panelGlow(th.s, panelGlowStrong)
                    PanelTape(color: th.s, stripe: 6, moving: status.active).frame(width: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: "\(U("Zestaw")): \(number)")
                        Text(verbatim: "\(U("Monitory")): \(data.monitors.count)")
                        if data.connected { Text(verbatim: J("接続中")) }
                    }
                    .font(PanelFont.mono()).foregroundStyle(th.s).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(height: 42)
                Text(verbatim: name).font(PanelFont.ui(name.count > 22 ? 13 : 15, .bold)).tracking(0.5)
                    .foregroundStyle(th.k).lineLimit(2).frame(maxHeight: 34, alignment: .top)
                    .panelGlow(th.k, panelGlowMid)
            }
            .frame(width: 214, alignment: .leading)
            VStack(spacing: 5) {
                HStack(spacing: 0) {
                    Text(verbatim: status.kanji).font(PanelFont.mark(28)).foregroundStyle(.black)
                        .lineLimit(1).minimumScaleFactor(0.5).padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PanelScanned(color: status.color))
                        .panelBlink(status.active)
                        .frame(width: 66)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: status.word).font(PanelFont.ui(20, .bold)).tracking(0.8)
                        Text(verbatim: status.sub).font(PanelFont.mono())
                    }
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .panelGlow(status.color, panelGlowSoft)   // the word and the line under it
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                // Double frame, which does not blink: a 1 pt line the content is cut to, 3 pt of
                // black, a 2 pt line, and a still glow in the state's color around it.
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(status.color, lineWidth: 1))
                .padding(5)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(status.color, lineWidth: 2)
                    .shadow(color: status.color.opacity(0.6), radius: 5))   // ponytail: one shadow on the line glows outwards and inwards; split in two if the inner glow must be weaker
                HStack {
                    Text(verbatim: status.top).font(PanelFont.ui(13, .bold)).tracking(2.6)
                    Spacer()
                    Text(verbatim: data.deviation).font(PanelFont.mono(11, .medium))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(PanelScanned(color: status.color))
                .panelBlink(status.active)
            }
            .foregroundStyle(status.color)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            // Honeycomb: number only, 5 per row; sets past the 10th are in the rail's list.
            ZStack(alignment: .topLeading) {
                ForEach(Array(model.profiles.prefix(10).enumerated()), id: \.element) { i, key in
                    let selected = key == data.key, connected = key == model.current
                    Button { model.selection = key } label: {
                        PanelSetHot(key: key) { hot in
                            Text(verbatim: String(format: "%02d", i + 1)).font(PanelFont.display(12))
                                .foregroundStyle(selected || hot ? .black : connected ? th.k : th.t)
                                .frame(width: 37, height: 29)
                                .background(PanelScanned(color: selected || hot && connected ? th.k : hot ? th.s : .black).clipShape(PanelHex()))
                                .panelBlink(connected && !hot)   // stands still, fully shown, under the pointer
                                .frame(width: 40, height: 32)
                                .background(PanelHex().fill(connected && !selected ? th.k : th.s))
                                .overlay(PanelGlow(on: hot && selected, shape: PanelHex()))
                                .contentShape(PanelHex())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.title(key))
                    .offset(x: CGFloat(i % 5) * 31 + 4, y: CGFloat(i / 5) * 34 + ((i % 5) % 2 == 1 ? 16 : 0))
                }
            }
            .frame(width: 172, height: 84, alignment: .topLeading)
            .padding(.top, 6)
        }
    }
}

// MARK: - Monitor zone

struct PanelZone: View {
    @EnvironmentObject var model: Model
    let th: PanelTheme
    let data: PanelData
    let picked: Int
    @ObservedObject var state: PanelState

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(data.monitors.enumerated()), id: \.element.uuid) { i, m in tab(i, m) }
            }
            .frame(height: 26)
            if data.monitors.indices.contains(picked) {
                let m = data.monitors[picked]
                detail(m)
                if m.tiles.isEmpty {
                    Text(data.hasSave ? "Tylko biurka" : "Ten zestaw nie ma zapisu. Ułóż przestrzenie i kliknij „Zapisz obecny układ”.")
                        .font(PanelFont.mono()).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { geo in
                        // Tiles take what they need, the connection field keeps at least 66 pt.
                        let perRow = max(1, Int((geo.size.width + 8) / 132))
                        let rows = (m.tiles.count + perRow - 1) / perRow
                        let wanted = CGFloat(20 + rows * 48 - 8)
                        VStack(spacing: 6) {
                            ScrollView(.vertical) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 8)], alignment: .leading, spacing: 8) {
                                    ForEach(m.tiles, id: \.index) { t in
                                        tile(t)
                                    }
                                }
                                .padding(.top, 20)
                            }
                            .frame(height: max(60, min(wanted, geo.size.height - 72)))
                            PanelField(th: th, monitor: m, connected: data.connected, hover: state.hover) { state.pointField($0) }
                                .overlay(alignment: .top) {
                                    Rectangle().stroke(th.s, style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(height: 1)
                                }
                        }
                    }
                }
            } else {
                Text("Wybierz zestaw monitorów").font(PanelFont.mono()).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, 6)
        .overlay(alignment: .top) { th.s.frame(height: 1) }
    }

    /// Same actions as the normal look: click marks the tile, double click shows its Space,
    /// ↗ on a missing app opens it and restores.
    private func tile(_ t: PanelTile) -> some View {
        let openable = data.connected && !t.entry.isDesktop && (t.state == .missing || t.state == .noFullScreen)
        return PanelTileView(th: th, tile: t, lit: state.hover == t.index, picked: t.space != nil && t.space == model.pickedSpace,
                             open: openable ? { model.restoreNow(openApps: true, only: t.entry.bundleID) } : nil,
                             openEnabled: !model.busy && model.trusted)
            .onHover { state.point(t.index, $0) }
            .onTapGesture(count: 2) { if let id = t.space { DispatchQueue.global().async { _ = goTo(id) } } }
            .simultaneousGesture(TapGesture().onEnded { if let id = t.space { model.pickedSpace = id } })
            .help(t.space == nil ? "" : String(localized: "Kliknij dwa razy, żeby przejść do tej przestrzeni"))
    }

    private func tab(_ i: Int, _ m: PanelMonitor) -> some View {
        let selected = i == picked
        let color = selected ? th.k : m.hasError ? th.e : m.differs ? th.w : th.k
        let number = String(format: "%02d", i + 1)
        return Button { state.monitorPick[data.key] = m.uuid; state.hover = nil } label: { PanelHot { hot in
            HStack(spacing: 6) {
                Text(verbatim: (data.monitors.count >= 3 ? "" : (J("画面") + " ")) + number + " · " + m.name)
                    .font(PanelFont.ui(data.monitors.count >= 3 ? 11 : 12, .bold)).lineLimit(1)
                Spacer(minLength: 0)
                Text(verbatim: "\(m.tiles.count) · " + (m.diffs > 0 ? U("\(m.diffs) różn.") : m.differs ? "≠" : "OK"))
                    .font(PanelFont.mono(11, .medium)).lineLimit(1).fixedSize()
            }
            .foregroundStyle(selected || hot ? .black : color)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PanelScanned(color: selected || hot ? color : .black))
            .overlay(Rectangle().strokeBorder(color, lineWidth: selected || m.differs ? 1.5 : 1))
            .overlay(PanelGlow(on: hot && selected, shape: Rectangle()))
            .contentShape(Rectangle())
        } }
        .buttonStyle(.plain)
    }

    /// The hovered tile in full; with nothing hovered, the monitor's first difference.
    private func detail(_ m: PanelMonitor) -> some View {
        let t = m.tiles.first { $0.index == state.hover } ?? m.tiles.first { $0.state != .ok } ?? m.tiles.first
        let name = t.map { $0.entry.isDesktop ? String(localized: "Biurko") : $0.entry.app } ?? ""
        let title = t.map { $0.entry.title.isEmpty ? "" : " — " + $0.entry.title } ?? ""
        let window = t?.entry.window.map { " · #\($0)" } ?? ""
        let pointed = t.map { $0.index == state.hover } ?? false   // under the pointer: the number on its state color
        return HStack(spacing: 10) {
            Text(verbatim: t?.num ?? "--").font(PanelFont.display(11)).foregroundStyle(pointed ? .black : th.k)
                .padding(.horizontal, 5).frame(height: 16)
                .background(pointed ? t.map { PanelScanned(color: $0.ring(th)) } : nil)
                .padding(.horizontal, -5)
            Text(verbatim: name + title + window).foregroundStyle(.white).truncationMode(.tail)
            Spacer(minLength: 0)
            if let t { Text(verbatim: t.word + " " + t.kanji).foregroundStyle(t.color(th)).fixedSize() }
        }
        .font(PanelFont.mono()).lineLimit(1)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .overlay(Rectangle().strokeBorder(th.s, lineWidth: 1))
    }
}

struct PanelTileView: View {
    let th: PanelTheme
    let tile: PanelTile
    var lit = false   // pointer over this Space: a ring around the bar, nothing else changes
    var picked = false   // clicked once (double click goes there): the same ring, kept
    var open: (() -> Void)? = nil   // a missing app: the end of the bar is a button that opens it
    var openEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(verbatim: tile.num).font(PanelFont.display(14)).lineLimit(1).minimumScaleFactor(0.6).frame(width: 24, height: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                PanelSlide(text: tile.app, font: PanelFont.ui(13, .bold), measure: PanelFont.nsUI(13), tracking: 0.5, on: lit)
                    .foregroundStyle(tile.state == .moved ? th.w : tile.state == .unsaved ? .black : tile.isError ? th.e : tile.entry.isDesktop ? th.k : .black)
                    .padding(.leading, 8).padding(.trailing, open == nil ? 8 : 30)   // the name ends 6 pt before the open segment
                    .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .leading)
                    .background(bar)
                    .overlay(alignment: .trailing) { if let open { openSegment(open) } }
                    .overlay(Rectangle().stroke(tile.ring(th), lineWidth: 2).padding(-3).opacity(lit || picked ? 1 : 0))   // 2 pt, 2 pt off the bar
                PanelSlide(text: tile.state == .ok ? tile.entry.title : tile.word, font: PanelFont.mono(), measure: PanelFont.nsMono(11), on: lit)
                    .foregroundStyle(tile.color(th)).padding(.leading, 8).frame(height: 15)
            }
            .transformEffect(CGAffineTransform(a: 1, b: -PanelHatch.tilt, c: 0, d: 1, tx: 0, ty: 0))   // bar tilted 5°
            .background(alignment: .top) {
                if tile.isError {
                    PanelHatch(color: th.e.opacity(0.3)).frame(height: 22 + PanelHatch.rise).offset(y: -PanelHatch.rise)
                }
            }
        }
        .frame(height: 40, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .animation(reduceMotion ? nil : .linear(duration: 0.075), value: lit)
    }

    /// Design RO variant A: the last 24 pt of the bar, inside its outline, tilted with it. Black
    /// over the stripes, a 1.5 pt line on the left, a drawn arrow; hover inverts like every panel
    /// button; disabled dims the arrow only.
    private func openSegment(_ action: @escaping () -> Void) -> some View {
        let inset: CGFloat = tile.state == .missing ? 1.5 : 2
        return Button(action: action) { PanelHot(enabled: openEnabled) { hot in
            PanelOpenArrow().stroke(hot ? Color.black : th.e, style: StrokeStyle(lineWidth: 1.8, lineCap: .square))
                .frame(width: 11, height: 11)
                .opacity(openEnabled ? 1 : 0.35)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(hot ? AnyView(PanelScanned(color: th.e)) : AnyView(Color.black))
                .overlay(alignment: .leading) { th.e.frame(width: 1.5) }
                .contentShape(Rectangle())
        } }
        .buttonStyle(.plain)
        .allowsHitTesting(openEnabled)   // not .disabled: that would dim the black and the line too
        .accessibilityAddTraits(openEnabled ? [] : .isStaticText)
        .frame(width: 24 - inset)
        .padding([.top, .bottom, .trailing], inset)
        .help("Otwórz, włącz pełny ekran i ustaw jak w zapisie (przywraca cały układ)")
    }

    /// State by shape, not only color: full bar, outline, excess color, outline with running stripes.
    @ViewBuilder private var bar: some View {
        switch tile.state {
        case .unsaved: PanelScanned(color: th.w)
        case .moved: Rectangle().strokeBorder(th.w, lineWidth: 2)
        case .missing, .noFullScreen:
            Rectangle().strokeBorder(th.e, lineWidth: tile.state == .missing ? 1.5 : 2)   // the stripes: PanelHatch, behind
        case .ok:
            if tile.entry.isDesktop { Rectangle().strokeBorder(th.k, lineWidth: 2) } else { PanelScanned(color: th.k) }
        }
    }
}

/// Open arrow, drawn on a 10×10 grid: the diagonal, then the head in the top right corner.
struct PanelOpenArrow: Shape {
    func path(in r: CGRect) -> Path {
        let x = { (v: CGFloat) in r.minX + v / 10 * r.width }, y = { (v: CGFloat) in r.minY + v / 10 * r.height }
        var p = Path()
        p.move(to: CGPoint(x: x(2), y: y(8))); p.addLine(to: CGPoint(x: x(8), y: y(2)))
        p.move(to: CGPoint(x: x(3.6), y: y(2))); p.addLine(to: CGPoint(x: x(8), y: y(2))); p.addLine(to: CGPoint(x: x(8), y: y(6.4)))
        return p
    }
}

/// One line of a tile. Too long: cut with "…"; under the pointer it slides to its end, waits,
/// slides back and again, while the pointer stays. Only the hovered tile moves (a whole bar of
/// sliding names is noise); with Reduce Motion it stays cut and the detail strip has it whole.
struct PanelSlide: View {
    let text: String
    let font: Font
    let measure: NSFont   // the same face as `font`
    var tracking: CGFloat = 0
    let on: Bool
    @Environment(\.panelStill) private var still

    var body: some View {
        GeometryReader { geo in
            let full = NSAttributedString(string: text, attributes: [.font: measure, .kern: tracking]).size().width
            let over = max(0, ceil(full) - geo.size.width)
            Group {
                if on && !still && over > 0 {
                    let run = Double(over) / 40   // 40 pt/s
                    Text(verbatim: text).fixedSize()
                        .keyframeAnimator(initialValue: CGFloat(0), repeating: true) { line, x in line.offset(x: x) } keyframes: { _ in
                            LinearKeyframe(0, duration: 0.5)
                            LinearKeyframe(-over, duration: run)
                            LinearKeyframe(-over, duration: 1.2)
                            LinearKeyframe(0, duration: run)
                        }
                } else {
                    Text(verbatim: text).lineLimit(1)
                }
            }
            .font(font).tracking(tracking)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .clipped()
    }
}

/// Saved order above, the bar now below, a line for each Space in both; bars with both counts.
struct PanelField: View {
    let th: PanelTheme
    let monitor: PanelMonitor
    let connected: Bool
    var hover: Int? = nil                          // tile index of the Space under the pointer
    var onHover: (Int?) -> Void = { _ in }         // the Space whose cell the pointer is over, nil for none
    @Environment(\.panelStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PanelLayers(key: "\(th.s)|\(monitor.links.map { "\($0.0)-\($0.1)" })|\(monitor.top.count)|\(monitor.bottom.count)|\(still)", build: moving)
                Canvas { context, size in draw(&context, size) }
                if connected { lost(geo.size) } else { noData(geo.size) }
                highlight(geo.size)
            }
            .animation(reduceMotion ? nil : .linear(duration: 0.075), value: hover)
            .onContinuousHover { phase in   // the cells only answer the pointer, they are not buttons
                if case .active(let at) = phase { onHover(tile(at: at, geo.size)) } else { onHover(nil) }
            }
        }
        .frame(minHeight: 66, maxHeight: .infinity)
        .accessibilityHidden(true)   // the tiles above say the same in words
    }

    private func topCell(_ i: Int, _ size: CGSize) -> CGRect { CGRect(x: layout(size).fx(i) - 12, y: 4, width: 24, height: 18) }
    private func bottomCell(_ j: Int, _ size: CGSize) -> CGRect { CGRect(x: layout(size).fx(j) - 12, y: size.height - 20, width: 24, height: 18) }

    private func tile(at point: CGPoint, _ size: CGSize) -> Int? {
        if let i = monitor.top.indices.first(where: { topCell($0, size).contains(point) }) { return monitor.tile(top: i) }
        if let j = monitor.bottom.indices.first(where: { bottomCell($0, size).contains(point) }) { return monitor.tile(bottom: j) }
        return nil
    }

    /// "SIGNAL LOST" where the line of a Space that is not open breaks off. Always in English.
    /// Left out when the plates would not fit: past 10 columns, columns closer than a plate and
    /// 6 pt, or no room above the now row; the broken line alone stays then.
    @ViewBuilder private func lost(_ size: CGSize) -> some View {
        let (fieldW, y0, y1, fx) = layout(size), h = y1 - y0, top = y0 + h * 0.4
        let columns = max(monitor.top.count, monitor.bottom.count, 1)
        let plate = CGSize(width: 54, height: 28)
        let missing = monitor.top.indices.filter { i in monitor.tile(top: i).map { monitor.tiles[$0].state == .missing } ?? false }
        if columns <= 10, (fieldW - 76) / CGFloat(columns) >= plate.width + 6, top + plate.height <= size.height - 22 {
            ForEach(missing, id: \.self) { i in
                VStack(spacing: 0) {
                    Text(verbatim: "SIGNAL").frame(height: 10)
                    Text(verbatim: "LOST").frame(height: 10)
                }
                .font(PanelFont.ui(10, .bold)).tracking(0.6).foregroundStyle(th.e)
                .frame(width: plate.width - 6, height: plate.height - 6)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(th.e, lineWidth: 1))
                .padding(3)   // 1.5 pt of black, then the 1.5 pt outer line
                .background(RoundedRectangle(cornerRadius: 5).fill(.black))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(th.e, lineWidth: 1.5).shadow(color: th.e.opacity(0.6), radius: 3))
                .panelBlink(true)   // the status block's clock: all plates together with it
                .position(x: fx(i), y: top + plate.height / 2)
                .allowsHitTesting(false)
            }
        }
    }

    /// A set that is not connected has no now row and no lines: "NO DATA" (always in English)
    /// with a turning sign in the middle of the empty field, smaller in a low field.
    @ViewBuilder private func noData(_ size: CGSize) -> some View {
        let (fieldW, y0, y1, _) = layout(size), room = y1 - y0 - 8
        if room >= 14 {
            let sign = room >= 24, scale = min(1, room / (sign ? 48 : 40))
            HStack(spacing: 14) {
                if sign {
                    PanelLayers(key: "\(th.s)|\(still)") { layer, size in
                        let u = size.width / 100, turning = CALayer()
                        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
                        func lines(_ points: [[CGFloat]], close: Bool = false) -> Path {
                            Path { p in
                                for l in points {
                                    p.addLines(stride(from: 0, to: l.count, by: 2).map { at(l[$0], l[$0 + 1]) })
                                    if close { p.closeSubpath() }
                                }
                            }
                        }
                        turning.frame = CGRect(origin: .zero, size: size)
                        turning.addSublayer(panelShape(lines([[50, 5, 75, 50], [50, 5, 25, 50], [50, 95, 75, 50], [50, 95, 25, 50]]), stroke: th.s.opacity(0.35), width: 1.5 * u))
                        turning.addSublayer(panelShape(lines([[5, 50, 95, 50], [50, 5, 50, 95]]), stroke: th.s.opacity(0.5), width: 2 * u))
                        turning.addSublayer(panelShape(lines([[50, 25, 75, 50, 50, 75, 25, 50]], close: true), stroke: th.s.opacity(0.5), width: 2 * u))
                        turning.addSublayer(panelShape(lines([[50, 5, 95, 50, 50, 95, 5, 50]], close: true), stroke: th.s, width: 3 * u))
                        turning.shadowColor = NSColor(th.s).cgColor   // a light glow
                        turning.shadowOffset = .zero
                        turning.shadowRadius = 2
                        turning.shadowOpacity = 0.6
                        var depth = CATransform3DIdentity
                        depth.m34 = -1 / 300
                        layer.sublayerTransform = depth   // perspective for the turn about the upright axis
                        layer.addSublayer(turning)
                        if !still { turning.add(panelLoop("transform.rotation.y", from: 0, to: 2 * .pi, 4.5), forKey: "turn") }
                    }
                    .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "NO DATA").font(PanelFont.ui(18, .bold)).tracking(3.6)
                    Text(verbatim: "未接続").font(PanelFont.kanji(15))   // Japanese in Chinese too: its English stand-in would say "NO DATA" twice
                }
                .foregroundStyle(th.s).fixedSize()
            }
            .scaleEffect(scale)
            .position(x: (76 + fieldW) / 2, y: (y0 + y1) / 2)
            .allowsHitTesting(false)
        }
    }

    /// The Space under the pointer: a ring around its cell in each row (2 pt, 2 pt off) and its
    /// line solid and thicker. Nothing else is dimmed.
    @ViewBuilder private func highlight(_ size: CGSize) -> some View {
        if let hover, monitor.tiles.indices.contains(hover) {
            let t = monitor.tiles[hover], (i, j) = monitor.cells(of: hover)
            let (_, y0, y1, fx) = layout(size), h = y1 - y0
            ZStack {
                if let i {
                    let r = topCell(i, size)
                    Rectangle().stroke(t.isError ? th.e : th.s, lineWidth: 2).frame(width: 30, height: 24).position(x: r.midX, y: r.midY)
                }
                if let j {
                    let r = bottomCell(j, size)
                    Rectangle().stroke(t.state == .unsaved ? th.w : th.k, lineWidth: 2).frame(width: 30, height: 24).position(x: r.midX, y: r.midY)
                }
                if let i, let j {
                    Path { p in
                        p.move(to: CGPoint(x: fx(i), y: y0))
                        p.addCurve(to: CGPoint(x: fx(j), y: y1), control1: CGPoint(x: fx(i), y: y0 + h * 0.55), control2: CGPoint(x: fx(j), y: y0 + h * 0.45))
                    }.stroke(th.k, lineWidth: 2.5).panelGlow(th.k, panelGlowMid)
                } else if let i, connected {
                    Path { p in p.move(to: CGPoint(x: fx(i), y: y0)); p.addLine(to: CGPoint(x: fx(i), y: y0 + h * 0.4)) }.stroke(th.e, lineWidth: 2.5).panelGlow(th.e, panelGlowMid)
                } else if let j {
                    Path { p in p.move(to: CGPoint(x: fx(j), y: y1)); p.addLine(to: CGPoint(x: fx(j), y: y0 + h * 0.6)) }.stroke(th.w, lineWidth: 2.5).panelGlow(th.w, panelGlowMid)
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func layout(_ size: CGSize) -> (fieldW: CGFloat, y0: CGFloat, y1: CGFloat, fx: (Int) -> CGFloat) {
        let fieldW = size.width - 114, left: CGFloat = 76, linkW = fieldW - left
        let count = CGFloat(max(monitor.top.count, monitor.bottom.count, 1))
        return (fieldW, 26, size.height - 24, { left + linkW * (CGFloat($0) + 0.5) / count })
    }

    /// Level of the "save" and "now" bars, full height = the bigger count.
    private func bars(_ size: CGSize) -> [(x: CGFloat, level: CGFloat, count: Int)] {
        let most = CGFloat(max(monitor.top.count, monitor.bottom.count, 1))
        return [monitor.top.count, monitor.bottom.count].enumerated().map { k, n in
            (layout(size).fieldW + 14 + CGFloat(k) * 55, (size.height - 36) * CGFloat(n) / most, n)
        }
    }

    /// The lines flow from the save down to now; the bars twitch in 4 steps.
    private func moving(_ layer: CALayer, _ size: CGSize) {
        let (_, y0, y1, fx) = layout(size), h = y1 - y0
        var links = Path()
        for (i, j) in monitor.links {
            links.move(to: CGPoint(x: fx(i), y: y0))
            links.addCurve(to: CGPoint(x: fx(j), y: y1), control1: CGPoint(x: fx(i), y: y0 + h * 0.55), control2: CGPoint(x: fx(j), y: y0 + h * 0.45))
        }
        layer.addSublayer(panelGlowLayer(links.strokedPath(StrokeStyle(lineWidth: 1.5)), color: th.k))
        let flow = panelShape(links, stroke: th.k, width: 1.5, dash: [6, 4])
        layer.addSublayer(flow)
        if !still {   // the one shape drawn again per frame: dashes cannot slide along a curve any other way
            flow.shouldRasterize = false
            flow.add(panelLoop("lineDashPhase", from: 0, to: -10, 0.4), forKey: "flow")
        }

        for (k, bar) in bars(size).enumerated() {
            var stripes = Path(), y: CGFloat = 0
            while y < bar.level {
                stripes.addRect(CGRect(x: 0, y: bar.level - y - min(5, bar.level - y), width: 45, height: min(5, bar.level - y)))
                y += 7
            }
            let column = panelShape(stripes, fill: k == 0 ? th.s : th.k)
            column.path = stripes.cgPath
            column.anchorPoint = CGPoint(x: 0.5, y: 1)   // grows from its foot
            column.frame = CGRect(x: bar.x, y: size.height - 16 - bar.level, width: 45, height: bar.level)
            column.addSublayer(panelGlowLayer(stripes, color: k == 0 ? th.s : th.k))   // same color over the stripes: only the halo shows; twitches along
            layer.addSublayer(column)
            if !still {
                column.add(panelSteps("transform.scale.y", [1, 0.965, 0.93, 0.895, 0.86, 0.895, 0.93, 0.965], every: 0.2, offset: k == 0 ? 0 : 1.2), forKey: "level")
            }
        }
    }

    private func draw(_ c: inout GraphicsContext, _ size: CGSize) {
        let mono = PanelFont.mono(), left: CGFloat = 76
        let (_, y0, y1, fx) = layout(size), h = y1 - y0
        c.draw(Text(verbatim: U("Zapis") + (" " + J("保存"))).font(mono).foregroundColor(th.t), at: CGPoint(x: 0, y: 6), anchor: .topLeading)
        c.draw(Text(verbatim: U("TERAZ")).font(mono).foregroundColor(th.t), at: CGPoint(x: 0, y: size.height - 4), anchor: .bottomLeading)

        var gone = Path(), new = Path()
        let linked = Set(monitor.links.map(\.0))
        if connected {
            for i in monitor.top.indices where !linked.contains(i) {
                gone.move(to: CGPoint(x: fx(i), y: y0)); gone.addLine(to: CGPoint(x: fx(i), y: y0 + h * 0.4))
            }
        }
        for (j, cell) in monitor.bottom.enumerated() where cell.state == .unsaved {
            new.move(to: CGPoint(x: fx(j), y: y1)); new.addLine(to: CGPoint(x: fx(j), y: y0 + h * 0.6))
        }
        panelGlowing(c, th.e).stroke(gone, with: .color(th.e), style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
        panelGlowing(c, th.w).stroke(new, with: .color(th.w), style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))

        // ponytail: cells are 24 pt wide and overlap past ~25 Spaces on one monitor; shrink them then.
        for (i, cell) in monitor.top.enumerated() {
            let r = topCell(i, size)
            let here = cell.state == .ok || cell.state == .moved   // on the bar now
            let color = here ? th.s : th.e
            let lit = panelGlowing(c, color)
            lit.stroke(Path(r.insetBy(dx: 0.5, dy: 0.5)), with: .color(color), style: StrokeStyle(lineWidth: 1, dash: here ? [] : [3, 2]))
            lit.draw(Text(verbatim: cell.label).font(mono).foregroundColor(color), at: CGPoint(x: r.midX, y: r.midY))
        }
        for (j, cell) in monitor.bottom.enumerated() {
            let r = bottomCell(j, size)
            let color = cell.state == .unsaved ? th.w : th.k
            panelGlowing(c, color).fill(Path(r), with: .color(color))
            panelScan(&c, r)
            c.draw(Text(verbatim: cell.label).font(mono).foregroundColor(.black), at: CGPoint(x: r.midX, y: r.midY))
        }
        if !connected {
            c.draw(Text(verbatim: U("Niepodłączony")).font(mono).foregroundColor(th.t), at: CGPoint(x: left, y: size.height - 4), anchor: .bottomLeading)
        }
        for (k, bar) in bars(size).enumerated() {
            let lit = panelGlowing(c, th.t)
            lit.draw(Text(verbatim: "\(bar.count)").font(mono).foregroundColor(th.t), at: CGPoint(x: bar.x + 22.5, y: size.height - 18 - bar.level), anchor: .bottom)
            lit.draw(Text(verbatim: k == 0 ? U("Zapis") : U("TERAZ")).font(mono).foregroundColor(th.t), at: CGPoint(x: bar.x + 22.5, y: size.height), anchor: .bottom)
        }
    }
}

// MARK: - Banner and ribbon

struct PanelBanner: View {
    let th: PanelTheme
    let status: PanelStatus
    @Environment(\.panelStill) private var still

    var body: some View {
        let unit = "\(status.top) · \(status.sub) · \(status.kanji) · "
        HStack(spacing: 0) {
            PanelTape(color: status.color, moving: status.active).frame(width: 110)
            PanelLayers(key: "\(status.color)|\(unit)|\(still)") { layer, size in
                // One strip of text, laid out once, sliding left by one repeat every 6.5 s (the
                // prototype's 26 s for four repeats).
                let attributes: [NSAttributedString.Key: Any] = [.font: PanelFont.nsUI(12), .kern: 2.4, .foregroundColor: NSColor.black]
                let unitW = NSAttributedString(string: unit, attributes: attributes).size().width
                let text = NSAttributedString(string: String(repeating: unit, count: Int(size.width / max(unitW, 1)) + 2), attributes: attributes)
                let strip = CATextLayer()
                strip.string = text
                strip.frame = CGRect(x: 0, y: (size.height - text.size().height) / 2, width: text.size().width.rounded(.up), height: text.size().height.rounded(.up))
                layer.addSublayer(strip)
                if !still { strip.add(panelLoop("transform.translation.x", from: 0, to: -unitW, 6.5), forKey: "run") }
            }
            .background(PanelScanned(color: status.color))   // the lines stand, only the text runs
            PanelTape(color: status.color, moving: status.active, reverse: true).frame(width: 110)
        }
        .frame(height: 18)
        .accessibilityHidden(true)   // repeats the status block
    }
}

struct PanelRibbonBlock: View {
    let th: PanelTheme
    let data: PanelData
    let tiles: [PanelTile]
    var hover: Int? = nil

    var body: some View {
        let percent = data.savedCount > 0 ? Int((Double(data.okCount) / Double(data.savedCount) * 100).rounded()) : 0
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(verbatim: "\(J("一致率")) \(U("Współczynnik zgodności")) \(data.okCount)/\(data.savedCount) · \(percent)%")
                    .font(PanelFont.ui(13, .semibold)).tracking(1.8).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Group {
                    th.s.frame(width: 18, height: 2)
                    Text(verbatim: U("Zapis") + (" " + J("保存")))
                    th.k.frame(width: 18, height: 2).padding(.leading, 8)
                    Text(verbatim: U("TERAZ"))
                }
                .font(PanelFont.mono()).fixedSize()
            }
            .frame(height: 18)
            PanelRibbon(th: th, tiles: tiles, hover: hover)
        }
        .padding(.top, 4)
        .overlay(alignment: .top) { th.s.frame(height: 1) }
    }
}

/// Two bundles of 9 lines, save and now, in opposite phase: they cross in one node per Space of
/// the picked monitor, and a difference bends its own bundle away from the node.
struct PanelRibbon: View {
    let th: PanelTheme
    let tiles: [PanelTile]
    var hover: Int? = nil   // the Space under the pointer: its label gets a thin ring
    @Environment(\.panelStill) private var still

    var body: some View {
        ZStack {
            PanelLayers(key: "\(th.s)|\(th.k)|\(tiles.map(\.state))|\(still)", build: moving)
            Canvas { context, size in draw(&context, size) }   // nodes and labels stay put, on top
                .padding(.horizontal, -Self.edge)              // room for the ring around a label at the chart's edge
        }
        .frame(height: 160)
        .accessibilityHidden(true)   // the tiles say the same in words
    }

    private static let H: CGFloat = 138, c: CGFloat = 69, amp: CGFloat = 26, x0: CGFloat = 36, edge: CGFloat = 6

    /// Node positions, and the wave's half period (few nodes: extra crossings between them).
    private func nodes(_ W: CGFloat) -> (xs: [CGFloat], wstep: CGFloat) {
        let step = (W - 72) / CGFloat(max(tiles.count - 1, 1))
        return (tiles.indices.map { Self.x0 + CGFloat($0) * step }, step / max(1, (step / 80).rounded()))
    }

    private func line(_ W: CGFloat, _ sign: CGFloat, _ saved: Bool, _ off: CGFloat, _ sc: CGFloat) -> Path {
        let (xs, wstep) = nodes(W)
        let bent: [CGFloat] = zip(tiles, xs).compactMap { t, x in t.state != .ok && (t.state == .unsaved) == saved ? x : nil }
        var p = Path()
        for x in stride(from: CGFloat(0), through: W, by: 6) {
            var y = sign * Self.amp * sc * sin(.pi * (x - Self.x0 + off) / wstep)
            for b in bent { y += (saved ? -1 : 1) * 0.95 * Self.amp * exp(-pow((x - b) / (0.3 * wstep), 2)) }
            let point = CGPoint(x: x, y: Self.c + y)
            if x == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }

    /// The bundles are computed once per data and size. Their layer is scaled about the middle
    /// line for the "breathing" (in steps of 140 ms, the nodes stay put; the bends at differences
    /// breathe along); a bright pulse runs along each middle line and a scanner crosses the chart.
    private func moving(_ layer: CALayer, _ size: CGSize) {
        let W = size.width
        let waves = CALayer()
        waves.frame = CGRect(x: 0, y: 0, width: W, height: Self.H)
        for (sign, saved, color) in [(CGFloat(-1), true, th.s), (1, false, th.k)] {
            var bundle = Path()
            for j in 0..<9 { bundle.addPath(line(W, sign, saved, CGFloat(j - 4) * 3.5, 1 - CGFloat(abs(j - 4)) * 0.04)) }
            waves.addSublayer(panelGlowLayer(bundle.strokedPath(StrokeStyle(lineWidth: 0.8)), color: color))
            waves.addSublayer(panelShape(bundle, stroke: color.opacity(0.8), width: 0.8))
        }
        layer.addSublayer(waves)
        guard !still else { return }
        // The pulse: both middle lines in white, seen through 46 pt windows that run to the right
        // (the prototype's 50 pt dash every 620 pt of line, which is about 575 pt across).
        // Its glow: the still glow of both whole lines, seen through the same running windows.
        let every: CGFloat = 575
        for glow in [true, false] {
            let pulse = CALayer(), windows = CALayer()
            pulse.frame = waves.bounds
            for (sign, saved) in [(CGFloat(-1), true), (1, false)] {
                let middle = line(W, sign, saved, 0, 1)
                pulse.addSublayer(glow ? panelGlowLayer(middle.strokedPath(StrokeStyle(lineWidth: 2)), color: .white) : panelShape(middle, stroke: .white, width: 2))
            }
            for n in 0...Int(W / every) + 1 {
                let window = CALayer()
                window.backgroundColor = NSColor.black.cgColor
                window.frame = CGRect(x: CGFloat(n - 1) * every, y: 0, width: 46, height: Self.H)
                windows.addSublayer(window)
            }
            windows.add(panelLoop("transform.translation.x", from: 0, to: every, 3.2), forKey: "pulse")
            pulse.mask = windows
            waves.addSublayer(pulse)
        }
        waves.add(panelSteps("transform.scale.y", (0..<21).map { CGFloat(0.72 + 0.28 * cos(Double($0) * 0.3)) }, every: 0.14), forKey: "breathe")

        let scanner = CAGradientLayer()
        scanner.colors = [NSColor.white.withAlphaComponent(0).cgColor, NSColor.white.withAlphaComponent(0.22).cgColor]
        scanner.startPoint = CGPoint(x: 0, y: 0.5)
        scanner.endPoint = CGPoint(x: 1, y: 0.5)
        scanner.frame = CGRect(x: -28, y: 0, width: 28, height: Self.H)
        let edge = CALayer()
        edge.backgroundColor = NSColor.white.cgColor
        edge.frame = CGRect(x: 27, y: 0, width: 1, height: Self.H)
        scanner.addSublayer(edge)
        scanner.add(panelLoop("position.x", from: -14, to: W - 14, 7), forKey: "scan")
        layer.addSublayer(scanner)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let W = size.width - 2 * Self.edge, H = Self.H, c = Self.c, amp = Self.amp
        ctx.translateBy(x: Self.edge, y: 0)
        let xs = nodes(W).xs
        var plus = Path(), calls = Path()
        for (i, x) in xs.enumerated() {
            let up = i % 2 == 0
            calls.move(to: CGPoint(x: x, y: up ? c - 8 : c + 8))
            calls.addLine(to: CGPoint(x: x, y: up ? c - amp - 12 : c + amp + 12))
            // "+" opposite the node's label, not next to a difference
            if [i - 1, i + 1].contains(where: { tiles.indices.contains($0) && tiles[$0].state != .ok }) { continue }
            let py = up ? c + amp + 21 : c - amp - 21
            plus.move(to: CGPoint(x: x - 5, y: py)); plus.addLine(to: CGPoint(x: x + 5, y: py))
            plus.move(to: CGPoint(x: x, y: py - 5)); plus.addLine(to: CGPoint(x: x, y: py + 5))
        }
        panelGlowing(ctx, th.k).stroke(plus, with: .color(th.k), lineWidth: 1)
        panelGlowing(ctx, th.t).stroke(calls, with: .color(th.t), lineWidth: 1)

        let mono = PanelFont.mono(), dense = tiles.count > 10
        for (i, t) in tiles.enumerated() {
            let x = xs[i], up = i % 2 == 0, ok = t.state == .ok
            let mark = CGRect(x: x - 5, y: 64, width: 10, height: 10)
            switch t.state {
            case .unsaved:
                ctx.fill(Path { p in
                    p.addLines([CGPoint(x: x, y: c - 7), CGPoint(x: x + 7, y: c), CGPoint(x: x, y: c + 7), CGPoint(x: x - 7, y: c)])
                    p.closeSubpath()
                }, with: .color(th.w))
            case .ok where !t.entry.isDesktop: ctx.fill(Path(mark), with: .color(th.k))
            default:
                ctx.fill(Path(mark), with: .color(.black))
                ctx.stroke(Path(mark.insetBy(dx: 1, dy: 1)), with: .color(ok ? th.k : t.color(th)), lineWidth: 2)
            }
            // Past 10 nodes a matching one keeps only its number; a difference keeps name and word.
            var y = up ? (ok ? c - amp - 28 : c - amp - 38) : c + amp + 14
            var around = CGRect.null
            for text in [(dense && ok) ? t.num : t.num + " " + t.app] + (ok ? [] : [dense ? t.short : t.word]) {
                let label = ctx.resolve(Text(verbatim: text).font(mono).foregroundColor(ok ? th.t : .black))
                let w = label.measure(in: CGSize(width: 600, height: 14)).width
                let cx = min(max(x, w / 2 + 5), W - w / 2 - 5)   // long labels stay inside the chart
                if !ok {
                    let plate = CGRect(x: cx - w / 2 - 5, y: y, width: w + 10, height: 14)
                    ctx.fill(Path(plate), with: .color(t.color(th)))
                    panelScan(&ctx, plate, top: around.isNull ? y : around.minY)
                }
                ctx.draw(label, at: CGPoint(x: cx, y: y + 7))
                around = around.union(CGRect(x: cx - w / 2 - 5, y: y, width: w + 10, height: 14))
                y += 14
            }
            if i == hover { ctx.stroke(Path(around.insetBy(dx: -3.75, dy: -3.75)), with: .color(t.ring(th)), lineWidth: 1.5) }   // 1.5 pt, 3 pt off
            ctx.fill(Path(CGRect(x: x - 0.5, y: H, width: 1, height: 5)), with: .color(th.t))
            ctx.draw(Text(verbatim: "\(i + 1)").font(mono).foregroundColor(th.t), at: CGPoint(x: x, y: H + 6), anchor: .top)
        }
        ctx.fill(Path(CGRect(x: 0, y: H - 0.75, width: W, height: 1.5)), with: .color(th.t))
    }
}

// MARK: - Rail

struct PanelRail: View {
    @EnvironmentObject var model: Model
    let th: PanelTheme
    let data: PanelData
    @ObservedObject var state: PanelState
    @AppStorage("autoSave") private var autoSave = false
    @AppStorage("autoRestore") private var autoRestore = true
    @AppStorage("restoreMethod") private var restoreMethod = "bridge"
    @AppStorage("settingsTab") private var settingsTab = "general"
    @Environment(\.panelStill) private var reduceMotion
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var hotkeys = Hotkeys.shared   // redraws the shortcut row once one is recorded

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sets
            settings
            deviation
            log
            Spacer(minLength: 0)
            actions
        }
    }

    private func heading(_ title: String, _ trailing: String = "", kanji: Bool = false) -> some View {
        HStack {
            Text(verbatim: title).font(PanelFont.ui(13, .semibold)).tracking(1.8)
            Spacer()
            Text(verbatim: trailing).font(kanji && !panelChinese ? PanelFont.kanji(13) : PanelFont.ui(13, .semibold)).foregroundStyle(kanji ? th.s : th.t)
        }
        .lineLimit(1)
        .frame(height: 20, alignment: .top)
        .overlay(alignment: .bottom) { th.s.frame(height: 1) }
    }

    /// Full names; the connected set keeps the match color. Past 7 sets the list scrolls.
    private var sets: some View {
        VStack(spacing: 0) {
            heading(U("Zestawy"), J("配置"), kanji: true)
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(Array(model.profiles.enumerated()), id: \.element) { i, key in
                        let selected = key == data.key, connected = key == model.current
                        Button { model.selection = key } label: { PanelSetHot(key: key) { hot in
                            HStack(spacing: 6) {
                                Text(verbatim: String(format: "%02d", i + 1)).font(PanelFont.display(11)).frame(width: 22, alignment: .leading)
                                Text(verbatim: model.title(key).uppercased()).font(PanelFont.ui(11, .semibold)).lineLimit(1)
                                Spacer(minLength: 0)
                                Text(verbatim: (connected ? (J("接続中") + " ") : "") + "\(model.spaceCount(key))").font(PanelFont.mono()).fixedSize()
                            }
                            .foregroundStyle(selected || hot ? .black : connected ? th.k : th.t)
                            .padding(.horizontal, 6)
                            .frame(height: 19)
                            .background(PanelScanned(color: selected || hot && connected ? th.k : hot ? th.t : .black))
                            .overlay(Rectangle().strokeBorder(selected || connected ? th.k : th.t, lineWidth: selected ? 1.5 : 1))
                            .overlay(PanelGlow(on: hot && selected, shape: Rectangle()))
                            .contentShape(Rectangle())
                        } }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if model.saved[key] != nil { Button("Usuń zapis", role: .destructive) { model.delete(key) } }
                        }
                    }
                }
                .padding(.top, 2)
            }
            .frame(height: CGFloat(min(model.profiles.count, 7)) * 21 + 2)
        }
    }

    private func segment(_ label: String, on: Bool, enabled: Bool = true, size: CGFloat = 12, width: CGFloat? = nil,
                         height: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) { PanelHot(enabled: enabled) { hot in
            Text(verbatim: label).font(PanelFont.ui(size, on ? .bold : .semibold)).strikethrough(!enabled)
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(on || hot ? .black : enabled ? th.k : th.t)
                .padding(.horizontal, width == nil ? 6 : 2)
                .frame(width: width, height: height)
                .frame(maxWidth: width == nil ? nil : .infinity)
                .background(PanelScanned(color: on || hot ? th.k : .black))
                .overlay(Rectangle().strokeBorder(enabled ? th.k : th.t, style: StrokeStyle(lineWidth: 1, dash: enabled ? [] : [3, 2])))
                .overlay(PanelGlow(on: hot && on, shape: Rectangle()))
                .contentShape(Rectangle())
        } }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row<Trailing: View>(_ label: String, @ViewBuilder _ trailing: () -> Trailing) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: label).font(PanelFont.ui(13, .semibold)).lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 2)
            trailing()
        }
        .frame(height: 28)
    }

    private func modeRow(_ label: String, _ auto: Binding<Bool>) -> some View {
        row(label) {
            HStack(spacing: 0) {
                segment(U("Ręcznie") + (" " + J("手動")), on: !auto.wrappedValue) { auto.wrappedValue = false }
                segment(U("Auto") + (" " + J("自動")), on: auto.wrappedValue) { auto.wrappedValue = true }
            }
        }
    }

    /// The same settings as the normal look, same keys.
    private var settings: some View {
        let language = appLanguage().isEmpty ? (Bundle.main.preferredLocalizations.first ?? "") : appLanguage()
        return VStack(alignment: .leading, spacing: 0) {
            heading(U("Ustawienia") + (" " + J("設定")))
            modeRow(U("Przywracanie"), $autoRestore)
            modeRow(U("Zapis") + (" " + J("保存")), $autoSave)
            VStack(spacing: 4) {
                HStack {
                    Text(verbatim: U("Metoda") + (" " + J("方式"))).font(PanelFont.ui(13, .semibold))
                    Spacer()
                    if !dragAvailable { Text(verbatim: U("Brak Karabinera")).font(PanelFont.mono()) }
                }
                .lineLimit(1)
                HStack(spacing: 0) {
                    ForEach([("drag", "Przeciąganie"), ("fullscreen", "Pełny ekran"), ("bridge", "Bezpośrednio")], id: \.0) { tag, name in
                        segment(String(localized: String.LocalizationValue(name)).uppercased(), on: restoreMethod == tag,
                                enabled: tag != "drag" || dragAvailable, size: 11, width: 88, height: 22) { restoreMethod = tag }
                    }
                }
            }
            .padding(.top, 3).padding(.bottom, 5)
            row(U("Skróty")) {
                Text(verbatim: Hotkeys.Action.allCases.compactMap(Hotkeys.label).joined(separator: " ")).font(PanelFont.mono()).lineLimit(1)
                segment(U("Ustaw"), on: false, width: 60) {
                    settingsTab = "shortcuts"
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }
            row(U("Język") + (" " + J("言語"))) {
                HStack(spacing: 0) {
                    ForEach(["pl", "en", "es", "zh-Hans"], id: \.self) { lang in
                        segment(String(lang.prefix(2)).uppercased(), on: language.hasPrefix(lang), enabled: !model.busy, width: 34) { setAppLanguage(lang) }
                    }
                }
                .frame(width: 136)
            }
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: U("Uruchamiaj przy logowaniu") + (" " + J("起動")))
                    Spacer(minLength: 2)
                    Button { model.setLoginItem(!model.loginItem) } label: { PanelHot { hot in
                        Text(verbatim: model.loginItem ? U("Wł") : U("Wył")).font(PanelFont.mono(11, .medium))
                            .foregroundStyle(model.loginItem || hot ? .black : th.k).padding(.horizontal, 6)
                            .background(PanelScanned(color: model.loginItem || hot ? th.k : .black))
                            .overlay(Rectangle().strokeBorder(th.k, lineWidth: 1))
                            .overlay(PanelGlow(on: hot && model.loginItem, shape: Rectangle()))
                    } }
                    .buttonStyle(.plain)
                }
                HStack {
                    Text(verbatim: U("Automat pilnuje monitorów") + (" " + J("監視")))
                    Spacer(minLength: 2)
                    Text(verbatim: model.trusted ? "OK" : "--").foregroundStyle(model.trusted ? th.k : th.e)
                }
                .padding(.top, 3)
                HStack {
                    Text(verbatim: U("Uprawnienie Dostępność"))
                    Spacer(minLength: 2)
                    if model.trusted {
                        Text(verbatim: "OK").foregroundStyle(th.k)
                    } else {
                        Button { model.requestAccess() } label: { PanelHot { hot in
                            Text(verbatim: U("Nadaj")).foregroundStyle(.black).padding(.horizontal, 6).background(PanelScanned(color: th.e))
                                .overlay(PanelGlow(on: hot, shape: Rectangle()))
                        } }
                        .buttonStyle(.plain)
                    }
                }
            }
            .font(PanelFont.mono()).lineLimit(1).minimumScaleFactor(0.6)
            .frame(height: 51)
        }
    }

    private var deviation: some View {
        VStack(spacing: 6) {
            heading(U("Odchylenie") + (" " + J("偏差")), data.deviation)
            HStack(spacing: 4) {
                zone(U("Zgodny"), data.hasSave && !data.differs, th.k)
                zone(U("Nadmiar"), data.hasUnsaved, th.w)
                zone(U("Braki"), data.hasError, th.e)
            }
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.325, d: 1, tx: 6, ty: 0))   // leaning 18°
        }
    }

    private func zone(_ label: String, _ on: Bool, _ color: Color) -> some View {
        Text(verbatim: label).font(PanelFont.ui(12, .bold)).tracking(0.5).lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(on ? .black : th.t)
            .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
            .background(PanelScanned(color: on ? color : .black))
            .overlay(Rectangle().strokeBorder(on ? color : th.t, lineWidth: 1))
    }

    /// The first differences, then the end of the app's log; while restoring, the log alone.
    private var log: some View {
        let diffs = model.busy ? [] : data.tiles.filter { $0.state != .ok }.prefix(2).map { ($0.state == .unsaved ? "+ " : $0.state == .moved ? "↔ " : "− ") + $0.app + " · " + $0.word }
        let found = diffs + state.logTail.suffix(3 - diffs.count).map { "> " + $0 }
        let lines = found.isEmpty ? ["> "] : found   // nothing to show: the prompt and the cursor alone
        // Typed out character by character, again every 9 s, each line 0.8 s after the one above:
        // the text sits on a layer and a mask uncovers it one character per step (a SwiftUI Text
        // retyped per character made the whole rail lay out again, ~20% of a core while typing).
        return PanelLayers(key: "\(th.t)|\(lines)|\(reduceMotion)") { layer, size in
            let font = PanelFont.nsMono(11)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(th.t)]
            let charW = NSAttributedString(string: "0", attributes: attributes).size().width
            let fits = max(1, Int(size.width / charW))
            for (i, full) in lines.enumerated() {
                let last = i == lines.count - 1
                let room = last ? max(1, Int((size.width - 2) / charW) - 1) : fits   // the last line leaves room for the cursor
                let line = full.count > room ? full.prefix(room - 1) + "…" : full   // cut here: one font, one width per character
                let text = CATextLayer()
                text.string = NSAttributedString(string: line, attributes: attributes)
                text.frame = CGRect(x: 0, y: CGFloat(i) * 15, width: size.width, height: 15)
                layer.addSublayer(text)
                let shown = line.count
                // A terminal's block cursor after the last line: decoration only, 0.5 s on, 0.5 s off.
                let cursor = CALayer()
                if last {
                    cursor.backgroundColor = NSColor(th.k).cgColor
                    cursor.anchorPoint = .zero
                    cursor.frame = CGRect(x: CGFloat(shown) * charW + 2, y: CGFloat(i) * 15 + 2, width: charW, height: 11)
                    layer.addSublayer(cursor)
                }
                guard !reduceMotion else { continue }
                cursor.add(panelSteps("opacity", [1, 0], every: 0.5), forKey: "blink")
                let cover = CALayer()
                cover.backgroundColor = NSColor.black.cgColor
                cover.anchorPoint = .zero
                cover.frame = text.bounds
                text.mask = cover
                let typing = CAKeyframeAnimation(keyPath: "bounds.size.width")
                typing.values = (0...shown).map { CGFloat($0) * charW } + [size.width]
                typing.keyTimes = (0...shown + 1).map { NSNumber(value: Double($0) / Double(shown + 1) * 0.1) } + [1]
                typing.calculationMode = .discrete
                typing.duration = 9
                typing.beginTime = cover.convertTime(CACurrentMediaTime(), from: nil) + Double(i) * 0.8
                typing.fillMode = .backwards   // nothing shown until the line's turn
                typing.repeatCount = .infinity
                cover.add(typing, forKey: "type")
                let follow = typing.copy() as! CAKeyframeAnimation   // the cursor rides just behind the typed text
                follow.keyPath = "position.x"
                follow.values = (0...shown).map { CGFloat($0) * charW + 2 } + [CGFloat(shown) * charW + 2]
                follow.beginTime = cursor.convertTime(CACurrentMediaTime(), from: nil) + Double(i) * 0.8
                cursor.add(follow, forKey: "follow")
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel(lines.joined(separator: ", "))
        .frame(height: 45, alignment: .top)
        .padding(.top, 4)
        .overlay(alignment: .top) { th.s.frame(height: 1) }
    }

    /// Save sits under a cover: the first click lifts it, the second saves (and replaces the save,
    /// so no extra question as in the normal look). Both act on the connected set only.
    private var actions: some View {
        let here = data.connected
        let canRestore = here && model.saved[model.current] != nil && !model.busy && model.trusted
        let differs = here && data.differs && data.hasSave
        let restoreColor = model.busy ? th.t : th.k
        return VStack(spacing: 8) {
            Button {
                if state.armed { state.armed = false; model.save(ask: false) } else { state.arm() }
            } label: { PanelHot(enabled: here) { hot in
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    Text(verbatim: U("Zapisz obecny układ")).font(PanelFont.ui(18, .bold)).tracking(1.4).lineLimit(1).minimumScaleFactor(0.6)
                    Text(verbatim: J("保存") + (model.saved[model.current] != nil ? " · " + U("Nadpisuje zapis") : "")).font(PanelFont.mono())
                }
                .foregroundStyle(state.armed || hot ? .black : th.s)
                .padding(.horizontal, 10).padding(.bottom, 8)
                .frame(maxWidth: .infinity, minHeight: 70, maxHeight: 70, alignment: .leading)
                .background(PanelScanned(color: state.armed || hot ? th.s : .black))
                .overlay(PanelGlow(on: hot && state.armed, shape: Rectangle()))
                .overlay(Rectangle().strokeBorder(th.s, lineWidth: 1.5))
                .overlay(alignment: .top) {
                    if !state.armed {
                        PanelTape(color: th.s, stripe: 8, period: 0.9)
                            .overlay {
                                Text(verbatim: U("Osłona · podnieś")).font(PanelFont.ui(12, .bold)).tracking(1.2)
                                    .foregroundStyle(th.s).padding(.horizontal, 8).background(Color.black)
                            }
                            .overlay(Rectangle().strokeBorder(th.s, lineWidth: 1.5))
                            .frame(height: 24)
                    }
                }
                .contentShape(Rectangle())
            } }
            .buttonStyle(.plain)
            .disabled(!here)
            .opacity(here ? 1 : 0.4)
            .accessibilityHint(state.armed ? "" : U("Osłona · podnieś"))
            Button { model.restoreNow() } label: { PanelHot(enabled: canRestore) { hot in
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: model.busy ? U("Przywracam…") : U("Przywróć")).font(PanelFont.ui(22, .bold)).tracking(1.8)
                    Text(verbatim: (J("復元") + " · ") + (!here ? U("Tylko podłączony zestaw") : !model.trusted ? U("Wymaga uprawnienia Dostępność dla tej apki")
                                               : differs ? U("Układ z zapisu") : data.hasSave ? U("Układ zgodny") : U("Brak zapisu")))
                        .font(PanelFont.mono())
                }
                .lineLimit(1).minimumScaleFactor(0.5)
                .foregroundStyle(differs && !model.busy || hot ? .black : restoreColor)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                .background(PanelScanned(color: differs && !model.busy || hot ? th.k : .black))
                .overlay(PanelGlow(on: hot && differs, shape: Rectangle()))
                .overlay(Rectangle().strokeBorder(restoreColor, lineWidth: differs || model.busy ? 1.5 : 1))
                .contentShape(Rectangle())
            } }
            .buttonStyle(.plain)
            .disabled(!canRestore)
            .opacity(here ? 1 : 0.4)
            Button { model.restoreNow(openApps: true) } label: { PanelHot(enabled: canRestore) { hot in
                Text(verbatim: U("Przywróć z brakującymi")).font(PanelFont.ui(15, .bold)).tracking(1.2)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(hot ? .black : restoreColor)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32, alignment: .leading)
                    .background(PanelScanned(color: hot ? th.k : .black))
                    .overlay(Rectangle().strokeBorder(restoreColor, lineWidth: 1))
                    .contentShape(Rectangle())
            } }
            .buttonStyle(.plain)
            .disabled(!canRestore)
            .opacity(here ? 1 : 0.4)
            .help("Najpierw otwiera zamknięte apki z zapisu, potem ustawia przestrzenie. Apki startują jak zwykle: ich stanu sprzed zamknięcia (np. kart przeglądarki) SpaceDock nie przywraca")
        }
    }
}

// MARK: - Check

/// `panel-shot <png> [width height [set]]`: the panel look drawn off screen from the real saves
/// and bars, to check it without a screen recording permission. Theme and language come from
/// the usual arguments (`-panelTheme 2 -AppleLanguages '(en)'`).
func panelShot(_ args: [String]) {
    guard let out = args.first else { print("panel-shot <png> [width height [set]]"); return }
    let number = { (i: Int) in args.count > i ? Double(args[i]) : nil }
    NSApplication.shared.setActivationPolicy(.accessory)
    let model = Model()
    if let i = number(3).map({ Int($0) - 1 }), model.profiles.indices.contains(i) { model.selection = model.profiles[i] }
    let size = NSSize(width: number(1) ?? 1100, height: number(2) ?? 700)
    let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -20000, y: -20000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    let host = NSHostingView(rootView: PanelView().environmentObject(model).environment(\.colorScheme, .dark))
    window.contentView = host
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(2))   // past the opening reveal
    // `-panelShotLive YES`: the picture the window server composed (layer shadows, blending), which
    // drawing the view into a bitmap leaves out. A process may take its own window without the
    // screen recording permission; the call is gone from the SDK, so it is looked up by name.
    if UserDefaults.standard.bool(forKey: "panelShotLive"), let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") {
        typealias Take = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        let take = unsafeBitCast(symbol, to: Take.self)
        if let image = take(.null, 1 << 3, UInt32(window.windowNumber), 1)?.takeRetainedValue() {   // this window only, without its frame
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
            return
        }
        print("panel-shot: the window server gave no picture, drawing the view instead")
    }
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
}
