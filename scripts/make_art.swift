// Generates ZenPad's app icon and DMG background.
//   swift scripts/make_art.swift icon <out.png>            1024×1024 app icon
//   swift scripts/make_art.swift dmg  <out.png> <scale>    660×400 pt DMG window background
//   swift scripts/make_art.swift appiconset <dir>          every AppIcon size into an .appiconset folder
import AppKit

let ink = NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)
let blueTop = NSColor(calibratedRed: 0.24, green: 0.49, blue: 1.0, alpha: 1)
let blueBottom = NSColor(calibratedRed: 0.13, green: 0.71, blue: 1.0, alpha: 1)

func render(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.cgContext.interpolationQuality = .high
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// Deterministic pseudo-random numbers so the brush texture is stable between runs.
struct Rand {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

/// An ensō: one confident brush stroke around a circle, thick where the brush lands and dry at the tail.
func drawEnso(_ ctx: CGContext, center: CGPoint, radius: CGFloat, width: CGFloat, color: NSColor, alpha: CGFloat = 1) {
    var rand = Rand(state: 11)
    let start = CGFloat.pi * 0.40          // brush lands at the upper right…
    let sweep = CGFloat.pi * 1.74          // …and travels counter-clockwise, leaving an opening
    let steps = 1600
    let dryStart: CGFloat = 0.78
    // Each bristle has its own lateral offset and lifts off the paper at a slightly different point.
    let bristles: [(offset: CGFloat, end: CGFloat, weight: CGFloat)] = (0..<7).map { i in
        let o = (CGFloat(i) / 6 - 0.5) * 0.9
        return (o, 0.90 + rand.next() * 0.10, 0.55 + rand.next() * 0.45)
    }
    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color.cgColor)
    func point(_ t: CGFloat, _ lateral: CGFloat) -> CGPoint {
        let wobble = sin(t * .pi * 2.6) * radius * 0.010 + sin(t * .pi * 6.1) * radius * 0.004
        let angle = start + sweep * t
        let r = radius + wobble + lateral
        return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
    }
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        // Width profile: quick swell where the brush lands, long gentle taper.
        let swell = min(1, t / 0.05)
        let taper = pow(1 - t * 0.85, 0.7)
        let w = width * (0.35 + 0.65 * swell) * taper
        if t < dryStart {
            let p = point(t, 0)
            let jitter = w * (0.97 + rand.next() * 0.06)
            ctx.fillEllipse(in: CGRect(x: p.x - jitter / 2, y: p.y - jitter / 2, width: jitter, height: jitter))
            continue
        }
        // Dry-brush tail: the stroke separates into bristles that thin out and break up.
        let dry = (t - dryStart) / (1 - dryStart)
        for b in bristles where t < b.end {
            let local = (t - dryStart) / (b.end - dryStart)
            if rand.next() < local * local * 0.7 { continue }
            let bw = w * (0.30 - 0.14 * local) * b.weight + width * 0.03
            let p = point(t, b.offset * w * (1 + dry * 0.25))
            ctx.fillEllipse(in: CGRect(x: p.x - bw / 2, y: p.y - bw / 2, width: bw, height: bw))
        }
        // Keep a solid core at the start of the dry section so the transition is soft.
        if dry < 0.35 {
            let p = point(t, 0)
            let cw = w * (1 - dry / 0.35) * 0.9
            ctx.fillEllipse(in: CGRect(x: p.x - cw / 2, y: p.y - cw / 2, width: cw, height: cw))
        }
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func drawCaret(_ ctx: CGContext, rect: CGRect) {
    let path = CGPath(roundedRect: rect, cornerWidth: rect.width / 2, cornerHeight: rect.width / 2, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: rect.width * 1.4, color: blueTop.withAlphaComponent(0.55).cgColor)
    ctx.addPath(path)
    ctx.setFillColor(blueTop.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [blueTop.cgColor, blueBottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    ctx.restoreGState()
}

func drawIcon(_ ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    ctx.addPath(squircle)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let paper = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.995, alpha: 1).cgColor,
                                    NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.91, alpha: 1).cgColor] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(paper, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    drawEnso(ctx, center: CGPoint(x: 512, y: 512), radius: 262, width: 92, color: ink)
    drawCaret(ctx, rect: CGRect(x: 497, y: 400, width: 30, height: 224))
    ctx.restoreGState()

    ctx.addPath(squircle)
    ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
    ctx.setLineWidth(2)
    ctx.strokePath()
}

func drawDMG(_ ctx: CGContext, size: CGSize) {
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [NSColor(calibratedRed: 0.995, green: 0.993, blue: 0.985, alpha: 1).cgColor,
                                 NSColor(calibratedRed: 0.935, green: 0.928, blue: 0.91, alpha: 1).cgColor] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: 0), options: [])

    // A faint ensō watermark behind everything.
    drawEnso(ctx, center: CGPoint(x: size.width / 2, y: size.height - 170), radius: 150, width: 40, color: ink, alpha: 0.05)

    // Arrow from the app icon (x 170) to Applications (x 490); icons sit 170 pt from the top.
    // Captions stay above y 340 so Finder's optional path bar never covers them.
    let y = size.height - 170
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 262, y: y))
    arrow.addQuadCurve(to: CGPoint(x: 392, y: y), control: CGPoint(x: 327, y: y + 26))
    ctx.saveGState()
    ctx.addPath(arrow)
    ctx.setStrokeColor(ink.withAlphaComponent(0.32).cgColor)
    ctx.setLineWidth(3)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [1, 9])
    ctx.strokePath()
    ctx.restoreGState()
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 384, y: y + 9))
    head.addLine(to: CGPoint(x: 396, y: y - 1))
    head.addLine(to: CGPoint(x: 383, y: y - 9))
    ctx.addPath(head)
    ctx.setStrokeColor(ink.withAlphaComponent(0.4).cgColor)
    ctx.setLineWidth(3)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let caption = NSAttributedString(string: "Drag ZenPad into Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: ink.withAlphaComponent(0.5),
        .paragraphStyle: style,
    ])
    caption.draw(in: CGRect(x: 0, y: 84, width: size.width, height: 20))
    let sub = NSAttributedString(string: "Then open it from Applications. ZenPad lives in your menu bar.", attributes: [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: ink.withAlphaComponent(0.35),
        .paragraphStyle: style,
    ])
    sub.draw(in: CGRect(x: 0, y: 64, width: size.width, height: 18))
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: make_art.swift icon|dmg|appiconset <out> [scale]")
    exit(1)
}

switch args[1] {
case "icon":
    try render(size: CGSize(width: 1024, height: 1024), scale: 1, draw: drawIcon).write(to: URL(fileURLWithPath: args[2]))
case "dmg":
    let scale = args.count > 3 ? CGFloat(Double(args[3]) ?? 1) : 1
    let size = CGSize(width: 660, height: 400)
    try render(size: size, scale: scale) { drawDMG($0, size: size) }.write(to: URL(fileURLWithPath: args[2]))
case "appiconset":
    let dir = URL(fileURLWithPath: args[2])
    let master = render(size: CGSize(width: 1024, height: 1024), scale: 1, draw: drawIcon)
    let image = NSImage(data: master)!
    var entries: [String] = []
    for base in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let px = base * scale
            let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
            let data = render(size: CGSize(width: px, height: px), scale: 1) { _ in
                image.draw(in: CGRect(x: 0, y: 0, width: px, height: px))
            }
            try data.write(to: dir.appendingPathComponent(name))
            entries.append("{ \"idiom\" : \"mac\", \"size\" : \"\(base)x\(base)\", \"scale\" : \"\(scale)x\", \"filename\" : \"\(name)\" }")
        }
    }
    let json = "{\n  \"images\" : [\n    " + entries.joined(separator: ",\n    ") + "\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    try json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
default:
    print("unknown target \(args[1])")
    exit(1)
}
