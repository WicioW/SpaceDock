import AppKit
import SwiftUI

// `dmg-background <out-folder>`: the picture behind the DMG window (tools/make-dmg.sh). Space with
// stars, the shuttle from the app icon flying from SpaceDock to Applications with three windows in
// its bay, and how to open the app the first time (it is not notarized). Writes background.png
// and background@2x.png; make-dmg.sh joins them into one TIFF for Retina and normal screens.
// The window is 640 × 400; icon centers must match make-dmg.sh.

enum DMGLayout {
    static let size = CGSize(width: 640, height: 400)
    static let app = CGPoint(x: 150, y: 150), applications = CGPoint(x: 490, y: 150), icon: CGFloat = 96
}

private struct DMGBackground: View {
    var body: some View {
        Canvas { c, size in
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.055, green: 0.078, blue: 0.14)))
            var seed: UInt64 = 7   // the same stars on every build
            func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
            for _ in 0..<90 {
                let p = CGPoint(x: next() * size.width, y: next() * size.height), r = 0.4 + next() * 1.1
                c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(.white.opacity(0.25 + next() * 0.5)))
            }

            // Shuttle (ShuttleEgg.swift's drawing, all three windows eaten) between the two icons.
            let s: CGFloat = 2.2, mid = CGPoint(x: (DMGLayout.app.x + DMGLayout.applications.x) / 2, y: DMGLayout.app.y)
            let tail = mid.x + (23 - 45) * s, nose = mid.x + (67 - 45) * s   // drawing spans x 23…67, center 45, 12
            var dots = Path(); dots.move(to: CGPoint(x: DMGLayout.app.x + DMGLayout.icon / 2 + 12, y: mid.y)); dots.addLine(to: CGPoint(x: tail - 6, y: mid.y))
            c.stroke(dots, with: .color(Color(red: 0.94, green: 0.55, blue: 0.18).opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 7]))
            var ahead = Path(); ahead.move(to: CGPoint(x: nose + 10, y: mid.y)); ahead.addLine(to: CGPoint(x: DMGLayout.applications.x - DMGLayout.icon / 2 - 12, y: mid.y))
            c.stroke(ahead, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 9]))
            var ship = c
            ship.translateBy(x: mid.x - 45 * s, y: mid.y - 12 * s)
            ship.scaleBy(x: s, y: s)
            ShuttleDrawing.draw(in: &ship, lit: true, offset: 220)

            // Finder writes the icon names in black on a background picture, also in dark mode: a
            // light plate under each name (centers measured on screen: 65 pt under the icon center).
            for center in [DMGLayout.app, DMGLayout.applications] {
                c.fill(Path(roundedRect: CGRect(x: center.x - 62, y: center.y + 54, width: 124, height: 22), cornerRadius: 6),
                       with: .color(Color(red: 0.87, green: 0.9, blue: 0.96)))
            }

            // First launch, under the icons and their names.
            let text = Color(red: 0.87, green: 0.9, blue: 0.96), dim = Color(red: 0.6, green: 0.65, blue: 0.75)
            var y: CGFloat = 262
            c.draw(Text("First launch").font(.system(size: 14, weight: .semibold)).foregroundColor(text), at: CGPoint(x: 60, y: y), anchor: .leading)
            for line in ["1.  Drag SpaceDock to Applications and open it.",
                         "2.  macOS says it can't verify the app: click Done.",
                         "3.  System Settings → Privacy & Security → Open Anyway."] {
                y += 24
                c.draw(Text(line).font(.system(size: 13)).foregroundColor(text), at: CGPoint(x: 60, y: y), anchor: .leading)
            }
            c.draw(Text("SpaceDock isn't notarized by Apple. Its code is open: github.com/WicioW/SpaceDock")
                    .font(.system(size: 11)).foregroundColor(dim), at: CGPoint(x: 60, y: y + 28), anchor: .leading)
        }
        .frame(width: DMGLayout.size.width, height: DMGLayout.size.height)
        .environment(\.colorScheme, .dark)
    }
}

@MainActor
func dmgBackground(_ args: [String]) {
    guard let folder = args.first else { print("dmg-background <folder>"); return }
    _ = NSApplication.shared
    for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
        let renderer = ImageRenderer(content: DMGBackground())
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("dmg-background: nie udało się narysować \(name)"); exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name))
    }
}
