// Generates docs/dmg-background.png for the DMG installer window.
//
// Usage:
//   swift scripts/make-dmg-background.swift docs/dmg-background.png
//
// The image is rendered at 2x and tagged 144 DPI so Finder displays it at
// 660x420 points on Retina screens.

import AppKit

let W: CGFloat = 660
let H: CGFloat = 420
let scale: CGFloat = 2
let pixelW = Int(W * scale)
let pixelH = Int(H * scale)

let image = NSImage(size: NSSize(width: pixelW, height: pixelH))
image.lockFocus()
guard let ctx = NSGraphicsContext.current else { exit(1) }
ctx.imageInterpolation = .high
ctx.cgContext.scaleBy(x: scale, y: scale)

// Background
let rect = NSRect(x: 0, y: 0, width: W, height: H)
NSGradient(colors: [
    NSColor(srgbRed: 0.031, green: 0.105, blue: 0.27, alpha: 1),
    NSColor(srgbRed: 0.039, green: 0.27, blue: 0.62, alpha: 1),
    NSColor(srgbRed: 0.067, green: 0.46, blue: 0.93, alpha: 1),
])!.draw(in: rect, angle: -58)

NSGradient(colors: [
    NSColor(white: 1, alpha: 0.16),
    NSColor(white: 1, alpha: 0),
])!.draw(fromCenter: NSPoint(x: 150, y: 360), radius: 0,
         toCenter: NSPoint(x: 150, y: 360), radius: 520, options: [])

func centered(_ text: String, font: NSFont, color: NSColor, y: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    let height = string.size().height
    string.draw(in: NSRect(x: 0, y: y, width: W, height: height + 2))
}

centered("DiskScope", font: .systemFont(ofSize: 30, weight: .bold), color: .white, y: 342)
centered("拖到 Applications 文件夹", font: .systemFont(ofSize: 13, weight: .medium),
         color: NSColor(white: 1, alpha: 0.78), y: 312)
centered("Drag to Applications", font: .systemFont(ofSize: 10.5),
         color: NSColor(white: 1, alpha: 0.48), y: 293)

// Arrow between the app icon and the Applications folder
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 252, y: 210))
arrow.line(to: NSPoint(x: 396, y: 210))
arrow.lineWidth = 5
arrow.lineCapStyle = .round
NSColor(white: 1, alpha: 0.30).setStroke()
arrow.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 374, y: 224))
head.line(to: NSPoint(x: 398, y: 210))
head.line(to: NSPoint(x: 374, y: 196))
head.lineWidth = 5
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

// Gatekeeper hint
centered("首次打开如被系统拦截：右键点按 App → 打开", font: .systemFont(ofSize: 9.5),
         color: NSColor(white: 1, alpha: 0.42), y: 40)
centered("If macOS blocks it, right-click the app and choose Open", font: .systemFont(ofSize: 8.5),
         color: NSColor(white: 1, alpha: 0.30), y: 25)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { exit(1) }

let output = CommandLine.arguments[1]
try! png.write(to: URL(fileURLWithPath: output))

let sips = Process()
sips.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
sips.arguments = ["-s", "dpiWidth", "144", "-s", "dpiHeight", "144", output, "--out", output]
try? sips.run()
sips.waitUntilExit()

print("written \(pixelW)x\(pixelH) -> \(output)")
