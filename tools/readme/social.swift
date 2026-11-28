// social.png: the picture shown when the repo or the site is linked (GitHub: Settings → General →
// Social preview, upload by hand; the site's og:image). 1280 × 640, like InvertedCursor's: a
// picture on top, the icon, name and tagline on a dark band below.
//   social <out.png> <icon.png> <picture.png> <cut>
// <cut>: the share of the picture's bottom to drop (the hero frame's caption), 0 for none. A
// picture wider than the field fills its width from the top (a window shot); a narrower one is
// fitted to the field's height on the hero's background color.
import AppKit

let args = CommandLine.arguments
guard args.count == 5, let icon = NSImage(contentsOfFile: args[2]), let picture = NSImage(contentsOfFile: args[3]), let cut = Double(args[4])
else { print("social <out.png> <icon.png> <picture.png> <cut>"); exit(1) }

let w: CGFloat = 1280, h: CGFloat = 640, field: CGFloat = 430
func rgb(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
// AppKit's origin is bottom left: the band is at y 0…210, the field above it.
rgb(0x11141B).setFill(); NSRect(x: 0, y: h - field, width: w, height: field).fill()   // the hero's background

let px = picture.representations.first.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? picture.size
let source = NSRect(x: 0, y: px.height * CGFloat(cut), width: px.width, height: px.height * CGFloat(1 - cut))   // from the bottom
picture.size = px
NSGraphicsContext.saveGraphicsState()
NSRect(x: 0, y: h - field, width: w, height: field).clip()
if source.width / source.height > w / field {   // wide: fill the width, top aligned
    let height = w * source.height / source.width
    picture.draw(in: NSRect(x: 0, y: h - height, width: w, height: height), from: source, operation: .sourceOver, fraction: 1)
} else {   // tall: fit the height, centered
    let width = field * source.width / source.height
    picture.draw(in: NSRect(x: (w - width) / 2, y: h - field, width: width, height: field), from: source, operation: .sourceOver, fraction: 1)
}
NSGraphicsContext.restoreGraphicsState()

rgb(0x131313).setFill(); NSRect(x: 0, y: 0, width: w, height: h - field).fill()
icon.draw(in: NSRect(x: 64, y: 49, width: 112, height: 112))
NSAttributedString(string: "SpaceDock", attributes: [.font: NSFont.systemFont(ofSize: 64, weight: .semibold), .foregroundColor: NSColor.white])
    .draw(at: CGPoint(x: 204, y: 92))
NSAttributedString(string: "Keeps your Spaces in order when monitors come and go",
                   attributes: [.font: NSFont.systemFont(ofSize: 30, weight: .regular), .foregroundColor: rgb(0xB4B4B4)])
    .draw(at: CGPoint(x: 206, y: 46))

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
print("Wrote \(args[1])")
