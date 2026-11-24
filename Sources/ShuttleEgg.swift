import SwiftUI

// Easter egg in the title row (TODO.md): the shuttle from the app icon seen from above, payload
// bay doors open, three Space thumbnails ahead of its nose. It lights up while pressed;
// 10 quick clicks and it flies forward, the thumbnails ending up in its bay. Drawn 1:1 with the
// approved sketch, in units of 0.1 pt (shuttle 34 × 23 pt, thumbnails 4.6 × 3.4 pt everywhere).

final class ShuttleEggState: ObservableObject {
    @Published var lit = false
    @Published var flightStart: Date?
    private var streak = 0, lastTap = Date.distantPast

    static let quickClick: TimeInterval = 0.4, clicksToFly = 10
    static let flight: TimeInterval = 2, hold: TimeInterval = 1.5

    /// `onFly` runs when the 10th quick click lands.
    func tap(onFly: () -> Void = {}) {
        guard flightStart == nil else { return }
        let now = Date()
        streak = now.timeIntervalSince(lastTap) <= Self.quickClick ? streak + 1 : 1
        lastTap = now
        guard streak >= Self.clicksToFly else { return }
        streak = 0
        flightStart = now
        onFly()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flight + Self.hold) { [weak self] in
            self?.flightStart = nil
            self?.lit = false
        }
    }

    /// Lit only while the button is held (the click itself lands on release, too late to light up).
    func press(_ down: Bool) {
        if flightStart == nil { lit = down }
    }
}

/// Plain button that reports press and release to the shuttle, so it lights up on mouse down.
struct ShuttlePress: ButtonStyle {
    let egg: ShuttleEggState
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.onChange(of: configuration.isPressed) { _, down in egg.press(down) }
    }
}

struct ShuttleEgg: View {
    @StateObject private var egg = ShuttleEggState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            egg.tap {
                // The flight unlocks the hidden panel look (Panel.swift) and switches to it once
                // the shuttle has landed; it stays unlocked and on across restarts.
                DispatchQueue.main.asyncAfter(deadline: .now() + ShuttleEggState.flight + ShuttleEggState.hold) {
                    UserDefaults.standard.set(true, forKey: PanelKey.unlocked)
                    UserDefaults.standard.set(true, forKey: PanelKey.on)
                }
            }
        } label: {
            TimelineView(.animation(paused: egg.flightStart == nil)) { timeline in
                let progress = egg.flightStart.map { start in
                    reduceMotion ? 1 : min(1, timeline.date.timeIntervalSince(start) / ShuttleEggState.flight)
                } ?? 0
                Canvas { context, _ in
                    ShuttleDrawing.draw(in: &context, lit: egg.lit || egg.flightStart != nil,
                                        offset: 220 * (1 - pow(1 - progress, 2)))   // eases out
                }
            }
            .frame(width: 68, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(ShuttlePress(egg: egg))
        .accessibilityHidden(true)   // decoration
    }
}

enum ShuttleDrawing {
    /// Thumbnails ahead of the nose (x of each, 0.1 pt) and in the bay; same size everywhere.
    static let ahead: [CGFloat] = [380, 440, 500], inBay: [CGFloat] = [116, 167, 218]
    static let thumb = CGSize(width: 46, height: 34), nose: CGFloat = 340
    static let cargo: [Color] = [Color(red: 0.24, green: 0.48, blue: 0.94),
                                 Color(red: 0.93, green: 0.35, blue: 0.55),
                                 Color(red: 0.18, green: 0.75, blue: 0.54)]

    /// `offset`: how far the shuttle has flown (0.1 pt). A thumbnail is in the bay once the
    /// nose has passed its middle.
    static func draw(in context: inout GraphicsContext, lit: Bool, offset: CGFloat) {
        context.translateBy(x: 11, y: 0)   // room for the flame behind the engines
        context.scaleBy(x: 0.1, y: 0.1)
        let eaten = ahead.filter { nose + offset >= $0 + thumb.width / 2 }.count
        for x in ahead.dropFirst(eaten) {
            context.fill(Path(roundedRect: CGRect(x: x, y: 103, width: thumb.width, height: thumb.height), cornerRadius: 5),
                         with: .style(.secondary))
        }
        var ship = context
        ship.translateBy(x: offset, y: 0)
        if lit { drawColored(&ship, cargo: eaten) } else { drawPlain(&ship) }
    }

    private static let wings = Path { p in
        p.addLines([CGPoint(x: 190, y: 96), CGPoint(x: 50, y: 6), CGPoint(x: 28, y: 6), CGPoint(x: 28, y: 234),
                    CGPoint(x: 50, y: 234), CGPoint(x: 190, y: 144)])
        p.closeSubpath()
    }
    private static let fuselage = Path { p in
        p.move(to: CGPoint(x: 10, y: 96))
        p.addLine(to: CGPoint(x: 280, y: 96))
        p.addCurve(to: CGPoint(x: 340, y: 120), control1: CGPoint(x: 318, y: 96), control2: CGPoint(x: 336, y: 110))
        p.addCurve(to: CGPoint(x: 280, y: 144), control1: CGPoint(x: 336, y: 130), control2: CGPoint(x: 318, y: 144))
        p.addLine(to: CGPoint(x: 10, y: 144))
        p.closeSubpath()
    }
    private static let doors = Path { p in
        p.addRect(CGRect(x: 110, y: 72, width: 160, height: 22))
        p.addRect(CGRect(x: 110, y: 146, width: 160, height: 22))
    }
    private static let bay = Path(CGRect(x: 110, y: 100, width: 160, height: 40))
    private static let engines = Path(CGRect(x: 0, y: 104, width: 12, height: 32))

    private static func flame(_ length: CGFloat, _ halfHeight: CGFloat) -> Path {
        Path { p in
            p.addLines([CGPoint(x: 0, y: 120 - halfHeight), CGPoint(x: -length, y: 120), CGPoint(x: 0, y: 120 + halfHeight)])
            p.closeSubpath()
        }
    }

    /// Resting: one tint like the other title bar glyphs, so it follows light and dark mode.
    private static func drawPlain(_ c: inout GraphicsContext) {
        c.fill(flame(70, 12), with: .style(.tertiary))
        for part in [wings, fuselage, engines] { c.fill(part, with: .style(.secondary)) }
        c.fill(doors, with: .style(.tertiary))
        c.fill(bay, with: .style(.quaternary))
    }

    /// Lit: the app icon's colors, flame burning, `cargo` thumbnails in the bay.
    private static func drawColored(_ c: inout GraphicsContext, cargo count: Int) {
        let hex = { (v: UInt32) in Color(red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255) }
        c.fill(flame(100, 16), with: .color(hex(0xF08C2E)))
        c.fill(flame(50, 8), with: .color(hex(0xFFD34D)))
        c.fill(wings, with: .color(hex(0xE9EDF4)))
        c.stroke(Path { p in p.addLines([CGPoint(x: 50, y: 6), CGPoint(x: 28, y: 6), CGPoint(x: 28, y: 234), CGPoint(x: 50, y: 234)]) },
                 with: .color(hex(0x262D47)), lineWidth: 8)
        c.fill(fuselage, with: .color(hex(0xF7F8FB)))
        c.fill(Path { p in p.addLines([CGPoint(x: 300, y: 104), CGPoint(x: 326, y: 112), CGPoint(x: 326, y: 128), CGPoint(x: 300, y: 136)]); p.closeSubpath() },
               with: .color(hex(0x141824)))   // cockpit windows
        c.fill(engines, with: .color(hex(0x0B0D14)))
        c.fill(Path(CGRect(x: 10, y: 116, width: 70, height: 8)), with: .color(hex(0x15181F)))   // tail fin
        c.fill(doors, with: .color(hex(0xC3CBDC)))
        c.stroke(Path { p in for x in [150, 190, 230] as [CGFloat] {
            p.move(to: CGPoint(x: x, y: 72)); p.addLine(to: CGPoint(x: x, y: 94))
            p.move(to: CGPoint(x: x, y: 146)); p.addLine(to: CGPoint(x: x, y: 168))
        } }, with: .color(hex(0x8A95AF)), lineWidth: 3)
        c.fill(bay, with: .color(hex(0x262D47)))
        for (i, x) in inBay.prefix(count).enumerated() {
            c.fill(Path(roundedRect: CGRect(x: x, y: 103, width: thumb.width, height: thumb.height), cornerRadius: 5), with: .color(.white))
            c.fill(Path(roundedRect: CGRect(x: x + 4, y: 110, width: 38, height: 23), cornerRadius: 3), with: .color(cargo[i]))
        }
    }
}
