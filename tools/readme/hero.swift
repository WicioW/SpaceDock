// Hero illustration for the README: a monitor and a laptop with their Spaces; unplugging piles
// everything on the laptop, plugging back leaves the mess, SpaceDock puts it back.
// Run by tools/readme/shots.sh: hero <out dir> <icon png> → frame-0000.png … (800×450 points, drawn at 2×)
import AppKit

let out = CommandLine.arguments[1], iconPath = CommandLine.arguments[2]
let W: CGFloat = 800, H: CGFloat = 450, scale: CGFloat = 2, fps = 15.0, total = 8.6
let icon = NSImage(contentsOfFile: iconPath)!

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

struct Tile { let id: String, symbol: String, label: String, color: NSColor }
let tiles: [Tile] = [
    Tile(id: "d1", symbol: "menubar.dock.rectangle", label: "Desktop", color: rgb(0x8E95A3)),
    Tile(id: "code", symbol: "chevron.left.forwardslash.chevron.right", label: "Code", color: rgb(0x3B82F6)),
    Tile(id: "web", symbol: "globe", label: "Browser", color: rgb(0xF97316)),
    Tile(id: "d2", symbol: "menubar.dock.rectangle", label: "Desktop", color: rgb(0x8E95A3)),
    Tile(id: "chat", symbol: "bubble.left.and.bubble.right.fill", label: "Chat", color: rgb(0xA855F7)),
    Tile(id: "music", symbol: "music.note", label: "Music", color: rgb(0xEC4899)),
    Tile(id: "d3", symbol: "menubar.dock.rectangle", label: "Desktop", color: rgb(0x8E95A3)),
]

// Screens: the monitor on the left, the laptop on the right.
let monitor = CGRect(x: 36, y: 62, width: 420, height: 236)
let laptop = CGRect(x: 494, y: 120, width: 270, height: 170)
typealias Arrangement = [String: (screen: CGRect, index: Int, count: Int)]
func arrange(_ m: [String], _ l: [String]) -> Arrangement {
    var a = Arrangement()
    for (i, id) in m.enumerated() { a[id] = (monitor, i, m.count) }
    for (i, id) in l.enumerated() { a[id] = (laptop, i, l.count) }
    return a
}
let ordered = arrange(["d1", "code", "web"], ["d2", "chat", "music"])
let unplugged = arrange([], ["d2", "code", "chat", "d1", "music", "web"])
let pluggedBack = arrange(["d3"], ["d2", "code", "chat", "d1", "music", "web"])

/// A Space's thumbnail in its screen's bar of Spaces (top strip, centered).
func slot(_ s: CGRect, _ i: Int, _ n: Int) -> CGRect {
    let gap: CGFloat = 7, pad: CGFloat = 12
    let w = min(s.width == monitor.width ? 96 : 66, (s.width - 2 * pad - gap * CGFloat(n - 1)) / CGFloat(max(n, 1)))
    let h = w * 0.64, rowW = w * CGFloat(n) + gap * CGFloat(n - 1)
    return CGRect(x: s.midX - rowW / 2 + CGFloat(i) * (w + gap), y: s.minY + 26, width: w, height: h)
}

func ease(_ x: Double) -> CGFloat { let t = min(max(x, 0), 1); return CGFloat(t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2) }
func lerp(_ a: CGRect, _ b: CGRect, _ p: CGFloat) -> CGRect {
    CGRect(x: a.minX + (b.minX - a.minX) * p, y: a.minY + (b.minY - a.minY) * p,
           width: a.width + (b.width - a.width) * p, height: a.height + (b.height - a.height) * p)
}

// Timeline (seconds).
let tUnplug = 1.4, tPlug = 3.2, tBanner = 4.4, tRestore = 4.9, tDone = 6.4, tFade = 8.1
let stagger = 0.08, move = 0.7

/// Where a tile is at time t, and how visible.
func state(_ id: String, _ t: Double) -> (CGRect, CGFloat)? {
    let order = Double(tiles.firstIndex { $0.id == id }!)
    func between(_ a: Arrangement, _ b: Arrangement, _ start: Double) -> CGRect? {
        guard let x = a[id], let y = b[id] else { return nil }
        return lerp(slot(x.screen, x.index, x.count), slot(y.screen, y.index, y.count), ease((t - start - order * stagger) / move))
    }
    if id == "d3" {   // the fresh desktop macOS makes on the monitor that came back; merged away on restore
        guard t >= tPlug else { return nil }
        let a = min(1, (t - tPlug) / 0.4) * (t < tRestore ? 1 : max(0, 1 - (t - tRestore) / 0.4))
        return a > 0 ? (slot(monitor, 0, 1), CGFloat(a)) : nil
    }
    if t < tPlug { return (between(ordered, unplugged, tUnplug)!, 1) }
    if t < tRestore { return (between(unplugged, pluggedBack, tPlug)!, 1) }
    return (between(pluggedBack, ordered, tRestore)!, 1)
}

func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSAttributedString {
    let f = NSFont.systemFont(ofSize: size, weight: weight)
    let font = f.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? f
    return NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
}
func drawCentered(_ a: NSAttributedString, x: CGFloat, y: CGFloat) {
    let sz = a.size(); a.draw(at: CGPoint(x: x - sz.width / 2, y: y - sz.height / 2))
}
func symbol(_ name: String, _ size: CGFloat, _ color: NSColor, in r: CGRect) {
    let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold).applying(.init(paletteColors: [color]))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
    let s = img.size
    img.draw(in: CGRect(x: r.midX - s.width / 2, y: r.midY - s.height / 2, width: s.width, height: s.height),
             from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

func drawScreen(_ s: CGRect, lit: CGFloat, isLaptop: Bool) {
    // Body: bezel, then the stand (monitor) or the base (laptop).
    let bezel = s.insetBy(dx: -8, dy: -8)
    rgb(0x2A2F3A).setFill(); NSBezierPath(roundedRect: bezel, xRadius: 12, yRadius: 12).fill()
    if isLaptop {
        rgb(0x3A404D).setFill()
        NSBezierPath(roundedRect: CGRect(x: bezel.minX - 22, y: bezel.maxY, width: bezel.width + 44, height: 10), xRadius: 5, yRadius: 5).fill()
    } else {
        rgb(0x2A2F3A).setFill()
        NSBezierPath(rect: CGRect(x: s.midX - 16, y: bezel.maxY, width: 32, height: 34)).fill()
        NSBezierPath(roundedRect: CGRect(x: s.midX - 70, y: bezel.maxY + 32, width: 140, height: 9), xRadius: 4, yRadius: 4).fill()
    }
    // Wallpaper, dimmed when unplugged.
    let wall = NSGradient(starting: rgb(0x1E3A8A), ending: rgb(0x5B21B6))!
    wall.draw(in: NSBezierPath(roundedRect: s, xRadius: 4, yRadius: 4), angle: -60)
    rgb(0x0B0D12, 1 - lit).setFill(); NSBezierPath(roundedRect: s, xRadius: 4, yRadius: 4).fill()
    // Bar of Spaces behind the thumbnails.
    rgb(0x000000, 0.28 * lit).setFill()
    NSBezierPath(rect: CGRect(x: s.minX, y: s.minY, width: s.width, height: isLaptop ? 88 : 106)).fill()
    if lit < 0.5 {
        symbol("powerplug", 30, rgb(0x6B7280), in: CGRect(x: s.midX - 20, y: s.midY - 28, width: 40, height: 40))
        drawCentered(text("Unplugged", 15, .semibold, rgb(0x6B7280)), x: s.midX, y: s.midY + 22)
    }
}

func drawTile(_ t: Tile, _ r: CGRect, _ alpha: CGFloat) {
    let path = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
    rgb(0xF4F5F7, alpha).setFill(); path.fill()
    t.color.withAlphaComponent(alpha).setStroke(); path.lineWidth = 2; path.stroke()
    symbol(t.symbol, r.width * 0.26, t.color.withAlphaComponent(alpha), in: CGRect(x: r.minX, y: r.minY + 2, width: r.width, height: r.height * 0.62))
    if r.width > 44 {
        drawCentered(text(t.label, min(11, r.width * 0.15), .semibold, rgb(0x374151, alpha)), x: r.midX, y: r.maxY - r.height * 0.2)
    }
}

/// SpaceDock's banner over a screen: red while arranging, then the layout it restored.
func drawBanner(on s: CGRect, t: Double, small: Bool) {
    guard t >= tBanner, t < tFade + 0.4 else { return }
    let inA = min(1, (t - tBanner) / 0.25), outA = t > tFade ? max(0, 1 - (t - tFade) / 0.3) : 1
    let a = CGFloat(inA * outA), done = t >= tDone
    let w: CGFloat = small ? 200 : 290, h: CGFloat = small ? 50 : 62
    let r = CGRect(x: s.midX - w / 2, y: s.maxY - h - (small ? 14 : 24) + (1 - CGFloat(inA)) * 10, width: w, height: h)
    let p = NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12)
    (done ? rgb(0x111827, 0.92 * a) : rgb(0xB91C1C, 0.95 * a)).setFill(); p.fill()
    let iconR = CGRect(x: r.minX + 10, y: r.midY - (h - 20) / 2, width: h - 20, height: h - 20)
    icon.draw(in: iconR, from: .zero, operation: .sourceOver, fraction: a, respectFlipped: true, hints: nil)
    let x = iconR.maxX + 10
    let top = done ? "Restored layout" : "Arranging Spaces…"
    let bottom = done ? "“Work”" : "don't touch the mouse"
    let t1 = text(top, small ? 10 : 12, .medium, NSColor.white.withAlphaComponent(0.8 * a))
    let t2 = text(bottom, small ? 15 : 19, .bold, done ? rgb(0x4ADE80, a) : NSColor.white.withAlphaComponent(a))
    t1.draw(at: CGPoint(x: x, y: r.midY - t1.size().height - 1))
    t2.draw(at: CGPoint(x: x, y: r.midY - 2))
}

func caption(_ t: Double) -> String {
    t < tUnplug ? "Your Spaces, in your order" :
    t < tPlug ? "Unplug the monitor: macOS piles everything on the laptop" :
    t < tBanner ? "Plug it back in: the order is gone" :
    t < tDone ? "SpaceDock puts every Space back…" : "…on the right display, in the saved order"
}

try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let frames = Int(total * fps)
for f in 0..<frames {
    let t = Double(f) / fps
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = ctx.cgContext
    cg.translateBy(x: 0, y: H * scale); cg.scaleBy(x: scale, y: -scale)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

    rgb(0x11141B).setFill(); NSBezierPath(rect: CGRect(x: 0, y: 0, width: W, height: H)).fill()
    // Monitor light: off between unplug and plug.
    let lit = t < tUnplug ? 1 : t < tPlug ? max(0.12, 1 - (t - tUnplug) / 0.3) : min(1, 0.12 + (t - tPlug) / 0.3)
    drawScreen(monitor, lit: CGFloat(lit), isLaptop: false)
    drawScreen(laptop, lit: 1, isLaptop: true)
    for tile in tiles { if let (r, a) = state(tile.id, t) { drawTile(tile, r, a) } }
    drawBanner(on: monitor, t: t, small: false)
    drawBanner(on: laptop, t: t, small: true)
    // Caption, crossfading is not worth it at 15 fps: it switches with the phase.
    drawCentered(text(caption(t), 19, .semibold, rgb(0xE5E7EB)), x: W / 2, y: H - 46)

    NSGraphicsContext.current = nil
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/frame-\(String(format: "%04d", f)).png"))
}
print("frames:", frames)
