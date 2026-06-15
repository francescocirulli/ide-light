#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct IconImage {
    let points: Int
    let scale: Int

    var pixels: Int {
        points * scale
    }

    var fileName: String {
        scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    }
}

let images = [
    IconImage(points: 16, scale: 1),
    IconImage(points: 16, scale: 2),
    IconImage(points: 32, scale: 1),
    IconImage(points: 32, scale: 2),
    IconImage(points: 128, scale: 1),
    IconImage(points: 128, scale: 2),
    IconImage(points: 256, scale: 1),
    IconImage(points: 256, scale: 2),
    IconImage(points: 512, scale: 1),
    IconImage(points: 512, scale: 2)
]

for image in images {
    let nsImage = NSImage(size: NSSize(width: image.pixels, height: image.pixels))
    nsImage.lockFocus()
    drawIcon(size: CGFloat(image.pixels))
    nsImage.unlockFocus()

    guard
        let tiff = nsImage.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Unable to render \(image.fileName)")
    }

    try png.write(to: iconset.appendingPathComponent(image.fileName))
}

try? FileManager.default.removeItem(at: output)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

try? FileManager.default.removeItem(at: iconset)
print("Generated \(output.path)")

func drawIcon(size: CGFloat) {
    let scale = size / 1024
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
    shadow.shadowBlurRadius = s(42)
    shadow.shadowOffset = NSSize(width: 0, height: -s(18))
    NSGraphicsContext.saveGraphicsState()
    shadow.set()

    let bodyRect = NSRect(x: s(72), y: s(82), width: s(880), height: s(860))
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: s(210), yRadius: s(210))
    NSGradient(colors: [
        NSColor(hex: 0x293037),
        NSColor(hex: 0x171A1D)
    ])?.draw(in: bodyPath, angle: 92)

    NSGraphicsContext.restoreGraphicsState()

    let innerRect = NSRect(x: s(118), y: s(132), width: s(788), height: s(760))
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: s(160), yRadius: s(160))
    NSGradient(colors: [
        NSColor(hex: 0x22272C),
        NSColor(hex: 0x101214)
    ])?.draw(in: innerPath, angle: 90)

    NSColor(hex: 0x3B434A).setStroke()
    innerPath.lineWidth = s(8)
    innerPath.stroke()

    let windowDotY = s(780)
    for (index, color) in [
        NSColor(hex: 0xFF5F57),
        NSColor(hex: 0xFFBD2E),
        NSColor(hex: 0x28C840)
    ].enumerated() {
        color.setFill()
        let x = s(220 + CGFloat(index) * 76)
        NSBezierPath(ovalIn: NSRect(x: x, y: windowDotY, width: s(42), height: s(42))).fill()
    }

    let panelRect = NSRect(x: s(192), y: s(246), width: s(640), height: s(438))
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: s(42), yRadius: s(42))
    NSColor(hex: 0x1A1D20).setFill()
    panelPath.fill()
    NSColor(hex: 0x343A40).setStroke()
    panelPath.lineWidth = s(5)
    panelPath.stroke()

    drawLine(x: 254, y: 580, width: 260, color: NSColor(hex: 0x65D1FF), size: size)
    drawLine(x: 254, y: 506, width: 520, color: NSColor(hex: 0xE7E7E7), size: size)
    drawLine(x: 254, y: 432, width: 420, color: NSColor(hex: 0x7AC88B), size: size)
    drawLine(x: 254, y: 358, width: 500, color: NSColor(hex: 0xC586C0), size: size)

    let beamPath = NSBezierPath()
    beamPath.move(to: NSPoint(x: s(742), y: s(710)))
    beamPath.line(to: NSPoint(x: s(846), y: s(710)))
    beamPath.line(to: NSPoint(x: s(626), y: s(304)))
    beamPath.line(to: NSPoint(x: s(516), y: s(304)))
    beamPath.close()
    NSGradient(colors: [
        NSColor(hex: 0x60CFFF, alpha: 0.95),
        NSColor(hex: 0x0A84FF, alpha: 0.16)
    ])?.draw(in: beamPath, angle: -68)

    NSColor(hex: 0x60CFFF).setStroke()
    let slash = NSBezierPath()
    slash.move(to: NSPoint(x: s(730), y: s(680)))
    slash.line(to: NSPoint(x: s(558), y: s(332)))
    slash.lineWidth = s(44)
    slash.lineCapStyle = .round
    slash.stroke()
}

func drawLine(x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor, size: CGFloat) {
    let scale = size / 1024
    color.setFill()
    let path = NSBezierPath(
        roundedRect: NSRect(x: x * scale, y: y * scale, width: width * scale, height: 28 * scale),
        xRadius: 14 * scale,
        yRadius: 14 * scale
    )
    path.fill()
}

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}
