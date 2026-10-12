import AppKit
import SwiftUI

struct MenuBarReading: Equatable {
    var provider: ProviderID
    var percent: Int?
}

@MainActor
enum MenuBarTitle {
    /// One status-item title: every visible tool's icon, then its own percent.
    static func attributedTitle(for readings: [MenuBarReading]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
        guard !readings.isEmpty else {
            result.append(symbol("gauge.medium", fallback: "AI", font: font, attributes: textAttributes))
            return result
        }
        for (index, reading) in readings.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "  ", attributes: textAttributes))
            }
            result.append(icon(for: reading.provider, font: font))
            result.append(NSAttributedString(string: " " + MenuBarLabel.valueTitle(percent: reading.percent), attributes: textAttributes))
        }
        return result
    }

    static func statusLength(for title: NSAttributedString) -> CGFloat {
        max(title.size().width + 8, 28)
    }

    private static func icon(for provider: ProviderID, font: NSFont) -> NSAttributedString {
        let image = ProviderMarkImage.image(for: provider)
        let attachment = NSTextAttachment()
        attachment.image = image
        let side: CGFloat = 13
        attachment.bounds = CGRect(x: 0, y: (font.capHeight - side) / 2, width: side, height: side)
        return NSAttributedString(attachment: attachment)
    }

    private static func symbol(
        _ name: String,
        fallback: String,
        font: NSFont,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: fallback) else {
            return NSAttributedString(string: fallback, attributes: attributes)
        }
        image.isTemplate = true
        let attachment = NSTextAttachment()
        attachment.image = image
        let side: CGFloat = 14
        attachment.bounds = CGRect(x: 0, y: (font.capHeight - side) / 2, width: side, height: side)
        return NSAttributedString(attachment: attachment)
    }
}

@MainActor
enum ProviderMarkImage {
    private static var cache: [ProviderID: NSImage] = [:]

    static func image(for provider: ProviderID) -> NSImage {
        if let cached = cache[provider] { return cached }
        let side: CGFloat = 13
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            draw(provider, in: rect)
            return true
        }
        image.isTemplate = false
        cache[provider] = image
        return image
    }

    private static func draw(_ provider: ProviderID, in rect: NSRect) {
        switch provider {
        case .claude:
            strokeAsterisk(in: rect, color: nsColor(for: provider))
        case .codex:
            let color = nsColor(for: provider)
            let box = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            color.setFill()
            box.fill()
            let text = ">_" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 7, weight: .heavy),
                .foregroundColor: NSColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
                withAttributes: attributes
            )
        case .cursor:
            nsColor(for: provider).setFill()
            cursorArrow(in: rect).fill()
        case .grok:
            let color = nsColor(for: provider)
            color.setStroke()
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.4, dy: 1.4))
            ring.lineWidth = 1.6
            ring.stroke()
            let slash = NSBezierPath()
            slash.lineWidth = 1.6
            slash.lineCapStyle = .round
            slash.move(to: NSPoint(x: rect.midX - 3, y: rect.midY - 1))
            slash.line(to: NSPoint(x: rect.midX + 3, y: rect.midY + 1))
            slash.stroke()
        }
    }

    private static func strokeAsterisk(in rect: NSRect, color: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        let radius = min(rect.width, rect.height) / 2 - 0.6
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 4
            let dx = cos(angle) * radius
            let dy = sin(angle) * radius
            path.move(to: NSPoint(x: rect.midX - dx, y: rect.midY - dy))
            path.line(to: NSPoint(x: rect.midX + dx, y: rect.midY + dy))
        }
        color.setStroke()
        path.stroke()
    }

    private static func cursorArrow(in rect: NSRect) -> NSBezierPath {
        let side = min(rect.width, rect.height)
        let origin = NSPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: origin.x + x / 12 * side, y: origin.y + (12 - y) / 12 * side)
        }
        let path = NSBezierPath()
        path.move(to: point(2.0, 1.0))
        path.line(to: point(2.0, 10.8))
        path.line(to: point(5.1, 7.7))
        path.line(to: point(7.6, 11.3))
        path.line(to: point(9.3, 10.2))
        path.line(to: point(6.7, 6.6))
        path.line(to: point(10.6, 6.4))
        path.close()
        return path
    }

    private static func nsColor(for provider: ProviderID) -> NSColor {
        switch provider {
        case .claude: NSColor(srgbRed: 0.18, green: 0.78, blue: 0.36, alpha: 1)
        case .codex: NSColor(srgbRed: 0.06, green: 0.64, blue: 0.50, alpha: 1)
        case .cursor: NSColor(srgbRed: 0.38, green: 0.56, blue: 0.98, alpha: 1)
        case .grok: NSColor(srgbRed: 0.95, green: 0.62, blue: 0.16, alpha: 1)
        }
    }
}

enum MenuBarLabel {
    static func title(percent: Int?) -> String? {
        guard let percent else { return nil }
        return "\(percent)%"
    }

    static func valueTitle(percent: Int?) -> String {
        title(percent: percent) ?? "–"
    }

    static func itemLabel(_ reading: MenuBarReading) -> String {
        if let percent = reading.percent {
            return "\(reading.provider.displayName) \(percent) percent"
        }
        return "\(reading.provider.displayName), no reading"
    }
}

struct ProviderMark: View {
    var provider: ProviderID

    var body: some View {
        switch provider {
        case .claude:
            AsteriskMark()
                .stroke(Self.color(for: provider), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
        case .codex:
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Self.color(for: provider))
                .overlay {
                    Text(">_")
                        .font(.system(size: 6, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
        case .cursor:
            CursorArrowMark()
                .fill(Self.color(for: provider))
        case .grok:
            GrokMark()
                .stroke(Self.color(for: provider), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }

    static func color(for provider: ProviderID) -> Color {
        switch provider {
        case .claude: Color(red: 0.18, green: 0.78, blue: 0.36)
        case .codex: Color(red: 0.06, green: 0.64, blue: 0.50)
        case .cursor: Color(red: 0.38, green: 0.56, blue: 0.98)
        case .grok: Color(red: 0.95, green: 0.62, blue: 0.16)
        }
    }
}

/// Eight-point star, the same compact mark as the menu-bar reference.
private struct AsteriskMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 4
            let dx = cos(angle) * radius
            let dy = sin(angle) * radius
            path.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
            path.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
        }
        return path
    }
}

private struct CursorArrowMark: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x / 12 * side, y: origin.y + y / 12 * side)
        }
        var path = Path()
        path.move(to: point(2.0, 1.0))
        path.addLine(to: point(2.0, 10.8))
        path.addLine(to: point(5.1, 7.7))
        path.addLine(to: point(7.6, 11.3))
        path.addLine(to: point(9.3, 10.2))
        path.addLine(to: point(6.7, 6.6))
        path.addLine(to: point(10.6, 6.4))
        path.closeSubpath()
        return path
    }
}

/// A ring with a tilted stroke, readable as Grok at menu-bar size.
private struct GrokMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let inset = side * 0.08
        path.addEllipse(in: rect.insetBy(dx: (rect.width - side) / 2 + inset, dy: (rect.height - side) / 2 + inset))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = side * 0.28
        path.move(to: CGPoint(x: center.x - radius, y: center.y + radius * 0.35))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y - radius * 0.35))
        return path
    }
}

enum MenuBarMath {
    static func percent(from snapshots: [UsageSnapshot]) -> Int? {
        let fractions = snapshots.compactMap(\.menuBarFraction)
        guard let maxFraction = fractions.max() else { return nil }
        return roundedPercent(maxFraction)
    }

    static func percent(from phases: [ProviderID: ProviderPhase]) -> Int? {
        percent(from: snapshots(from: phases))
    }

    static func readings(in phases: [ProviderID: ProviderPhase], visible: [ProviderID]) -> [MenuBarReading] {
        visible.map { provider in
            let percent = snapshot(for: provider, in: phases)?.menuBarFraction.map(roundedPercent)
            return MenuBarReading(provider: provider, percent: percent)
        }
    }

    static func roundedPercent(_ fraction: Double) -> Int {
        min(100, max(0, Int((fraction * 100).rounded())))
    }

    static func snapshots(from phases: [ProviderID: ProviderPhase]) -> [UsageSnapshot] {
        ProviderID.allCases.compactMap { snapshot(for: $0, in: phases) }
    }

    static func snapshot(for provider: ProviderID, in phases: [ProviderID: ProviderPhase]) -> UsageSnapshot? {
        switch phases[provider] {
        case .loaded(let snapshot):
            return snapshot
        case .loading(let stale):
            return stale
        case .failed(_, let stale):
            return stale
        case .unconfigured, .none:
            return nil
        }
    }
}
