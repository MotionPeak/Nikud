#!/usr/bin/env swift
import AppKit
import Foundation

// Generates the Nikud app icon at every macOS size.
// Usage: swift Tools/GenerateIcon.swift [outputDir]

_ = NSApplication.shared

let outputDir: String = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/Nikud/Assets.xcassets/AppIcon.appiconset"

func drawIcon(size S: CGFloat) -> Data {
    let px = Int(S)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("bitmap rep") }
    rep.size = NSSize(width: S, height: S)

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("ctx") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Squircle geometry following the macOS icon grid.
    let pad = (S * 0.0977).rounded()
    let sq = NSRect(x: pad, y: pad, width: S - 2 * pad, height: S - 2 * pad)
    let radius = sq.width * 0.2245
    let body = NSBezierPath(roundedRect: sq, xRadius: radius, yRadius: radius)

    // Soft drop shadow from a solid fill.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowOffset = NSSize(width: 0, height: -S * 0.013)
    shadow.shadowBlurRadius = S * 0.040
    shadow.set()
    NSColor(srgbRed: 0.30, green: 0.22, blue: 0.65, alpha: 1).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Diagonal brand gradient.
    if let grad = NSGradient(colors: [
        NSColor(srgbRed: 0.561, green: 0.498, blue: 0.965, alpha: 1),
        NSColor(srgbRed: 0.278, green: 0.200, blue: 0.651, alpha: 1)
    ]) {
        grad.draw(in: body, angle: -55)
    }

    // Subtle top highlight.
    if let highlight = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.16),
        NSColor.white.withAlphaComponent(0.0)
    ]) {
        highlight.draw(in: body, angle: -90)
    }

    let cx = S / 2

    // Hebrew letter aleph.
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let letter = NSAttributedString(string: "א", attributes: [
        .font: NSFont.systemFont(ofSize: S * 0.52, weight: .black),
        .foregroundColor: NSColor.white.withAlphaComponent(0.98),
        .paragraphStyle: para
    ])
    let lSize = letter.size()
    letter.draw(in: NSRect(
        x: cx - lSize.width / 2,
        y: S / 2 - lSize.height / 2 + S * 0.052,
        width: lSize.width, height: lSize.height
    ))

    // Three nikud dots beneath the letter.
    let dotR = S * 0.0295
    let gap = S * 0.105
    let dotY = S / 2 - S * 0.210
    NSColor.white.withAlphaComponent(0.90).setFill()
    for i in -1...1 {
        let r = NSRect(
            x: cx + CGFloat(i) * gap - dotR, y: dotY - dotR,
            width: dotR * 2, height: dotR * 2
        )
        NSBezierPath(ovalIn: r).fill()
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("png encode")
    }
    return data
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for s in sizes {
    let path = "\(outputDir)/icon_\(s).png"
    do {
        try drawIcon(size: CGFloat(s)).write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    } catch {
        print("FAILED \(path): \(error)")
        exit(1)
    }
}
print("Icon generation complete.")
