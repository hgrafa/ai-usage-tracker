import AppKit
import Foundation

/// Scales packaging/logo.png into the app icon set and draws the disk-image background.
/// The logo is a painted image, so it stays a bitmap. A flat SVG of that shading would not animate cleanly.

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconSet = root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let packaging = root.appendingPathComponent("packaging", isDirectory: true)
let docs = root.appendingPathComponent("docs", isDirectory: true)

try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: packaging, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)

let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
let paper = NSColor(srgbRed: 0.957, green: 0.957, blue: 0.961, alpha: 1)

func bitmap(width: Int, height: Int, draw: (CGContext) -> Void) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "render", code: 1)
    }
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    if let ctx = NSGraphicsContext.current?.cgContext {
        draw(ctx)
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 2)
    }
    return png
}

func scaledLogo(_ logo: NSImage, side: Int) throws -> Data {
    try bitmap(width: side, height: side) { _ in
        NSGraphicsContext.current?.imageInterpolation = .high
        logo.draw(
            in: NSRect(x: 0, y: 0, width: side, height: side),
            from: NSRect(origin: .zero, size: logo.size),
            operation: .copy,
            fraction: 1
        )
    }
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let logoURL = packaging.appendingPathComponent("logo.png")
guard let logo = NSImage(contentsOf: logoURL) else {
    throw NSError(domain: "render", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing \(logoURL.path)"])
}
for (name, side) in sizes {
    try scaledLogo(logo, side: side).write(to: iconSet.appendingPathComponent(name))
}
try scaledLogo(logo, side: 512).write(to: docs.appendingPathComponent("icon-512.png"))

let backgroundWidth = 660
let backgroundHeight = 400
let background = try bitmap(width: backgroundWidth, height: backgroundHeight) { ctx in
    let width = CGFloat(backgroundWidth)
    let height = CGFloat(backgroundHeight)
    ctx.setFillColor(ink.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let colors = [NSColor.white.withAlphaComponent(0.05).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
    if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: width * 0.5, y: height * 0.45),
            startRadius: 0,
            endCenter: CGPoint(x: width * 0.5, y: height * 0.45),
            endRadius: 280,
            options: []
        )
    }

    func well(at point: CGPoint) {
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addEllipse(in: CGRect(x: point.x - 58, y: point.y - 58, width: 116, height: 116))
        ctx.strokePath()
    }

    // Icon slots match packaging/dmg_settings.py. y is from the bottom, same as dmgbuild.
    let left = CGPoint(x: 160, y: 190)
    let right = CGPoint(x: 500, y: 190)
    well(at: left)
    well(at: right)

    ctx.setStrokeColor(paper.withAlphaComponent(0.55).cgColor)
    ctx.setFillColor(paper.withAlphaComponent(0.55).cgColor)
    ctx.setLineWidth(1.5)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 250, y: left.y))
    ctx.addLine(to: CGPoint(x: 400, y: left.y))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: 386, y: left.y + 11))
    ctx.addLine(to: CGPoint(x: 404, y: left.y))
    ctx.addLine(to: CGPoint(x: 386, y: left.y - 11))
    ctx.closePath()
    ctx.fillPath()

    let title = "AI Usage" as NSString
    let titleFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: paper
    ]
    let titleSize = title.size(withAttributes: titleAttrs)
    title.draw(
        at: CGPoint(x: (width - titleSize.width) / 2, y: height - 78),
        withAttributes: titleAttrs
    )

    let caption = "Drag AI Usage into Applications" as NSString
    let captionFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let captionAttrs: [NSAttributedString.Key: Any] = [
        .font: captionFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.62)
    ]
    let captionSize = caption.size(withAttributes: captionAttrs)
    caption.draw(
        at: CGPoint(x: (width - captionSize.width) / 2, y: 46),
        withAttributes: captionAttrs
    )
}
try background.write(to: packaging.appendingPathComponent("dmg-background.png"))

let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contents.write(to: iconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let catalog = """
{
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try catalog.write(
    to: root.appendingPathComponent("App/Assets.xcassets/Contents.json"),
    atomically: true,
    encoding: .utf8
)

print("wrote icon set, docs/icon-512.png, packaging/dmg-background.png")
