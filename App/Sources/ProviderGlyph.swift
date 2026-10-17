import AppKit
import SwiftUI

enum ProviderGlyph {
    static func usesEvenOddFill(_ provider: ProviderID) -> Bool {
        provider == .codex || provider == .grok || provider == .openrouter || provider == .moonshot
    }

    static func makePath(for provider: ProviderID) -> CGPath {
        switch provider {
        case .claude:
            SVGPathParser.path(from: claudeSpark)
        case .codex:
            SVGPathParser.path(from: codexCloud)
        case .cursor:
            SVGPathParser.path(from: cursorCube)
        case .grok:
            grokBotFace()
        case .openrouter:
            ring()
        case .deepseek:
            CGPath(ellipseIn: CGRect(x: 1, y: 1, width: 22, height: 22), transform: nil)
        case .moonshot:
            crescent()
        }
    }

    static func fittedPath(for provider: ProviderID, in rect: CGRect) -> CGPath {
        fit(makePath(for: provider), in: rect.insetBy(dx: 0.3, dy: 0.3))
    }

    static func fit(_ path: CGPath, in rect: CGRect) -> CGPath {
        let bounds = path.boundingBoxOfPath
        guard bounds.width > 0, bounds.height > 0, bounds.width.isFinite, bounds.height.isFinite else { return path }
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: rect.midX, y: rect.midY)
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: -bounds.midX, y: -bounds.midY)
        return path.copy(using: &transform) ?? path
    }

    // Claude spark from simple-icons (matches the mark in Claude.app). Brand fill #D97757.
    private static let claudeSpark = "m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"

    // Codex cloud-and-prompt from the mark shipped in ChatGPT.app. Gradient #B1A7FF, #7A9DFF, #3941FF.
    private static let codexCloud = "M8.086.457a6.105 6.105 0 013.046-.415c1.333.153 2.521.72 3.564 1.7a.117.117 0 00.107.029c1.408-.346 2.762-.224 4.061.366l.063.03.154.076c1.357.703 2.33 1.77 2.918 3.198.278.679.418 1.388.421 2.126a5.655 5.655 0 01-.18 1.631.167.167 0 00.04.155 5.982 5.982 0 011.578 2.891c.385 1.901-.01 3.615-1.183 5.14l-.182.22a6.063 6.063 0 01-2.934 1.851.162.162 0 00-.108.102c-.255.736-.511 1.364-.987 1.992-1.199 1.582-2.962 2.462-4.948 2.451-1.583-.008-2.986-.587-4.21-1.736a.145.145 0 00-.14-.032c-.518.167-1.04.191-1.604.185a5.924 5.924 0 01-2.595-.622 6.058 6.058 0 01-2.146-1.781c-.203-.269-.404-.522-.551-.821a7.74 7.74 0 01-.495-1.283 6.11 6.11 0 01-.017-3.064.166.166 0 00.008-.074.115.115 0 00-.037-.064 5.958 5.958 0 01-1.38-2.202 5.196 5.196 0 01-.333-1.589 6.915 6.915 0 01.188-2.132c.45-1.484 1.309-2.648 2.577-3.493.282-.188.55-.334.802-.438.286-.12.573-.22.861-.304a.129.129 0 00.087-.087A6.016 6.016 0 015.635 2.31C6.315 1.464 7.132.846 8.086.457zm-.804 7.85a.848.848 0 00-1.473.842l1.694 2.965-1.688 2.848a.849.849 0 001.46.864l1.94-3.272a.849.849 0 00.007-.854l-1.94-3.393zm5.446 6.24a.849.849 0 000 1.695h4.848a.849.849 0 000-1.696h-4.848z"

    // Grok Bot face from Grok Bot.app (com.anysphere.sand): a rounded tile with two eye slots.
    private static func grokBotFace() -> CGPath {
        let path = CGMutablePath()
        path.addPath(CGPath(roundedRect: CGRect(x: 1.5, y: 1.5, width: 21, height: 21), cornerWidth: 6.2, cornerHeight: 6.2, transform: nil))
        path.addPath(CGPath(roundedRect: CGRect(x: 7.4, y: 7.2, width: 3.5, height: 6.2), cornerWidth: 1.75, cornerHeight: 1.75, transform: nil))
        path.addPath(CGPath(roundedRect: CGRect(x: 13.1, y: 7.2, width: 3.5, height: 6.2), cornerWidth: 1.75, cornerHeight: 1.75, transform: nil))
        return path
    }

    private static func ring() -> CGPath {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: 1, y: 1, width: 22, height: 22))
        path.addEllipse(in: CGRect(x: 6.5, y: 6.5, width: 11, height: 11))
        return path
    }

    private static func crescent() -> CGPath {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: 1, y: 1, width: 22, height: 22))
        path.addEllipse(in: CGRect(x: 9, y: 2, width: 18, height: 20))
        return path
    }

    // Cursor cube from the cursor.com header lockup. The mark is monochrome.
    private static let cursorCube = "m466.383 137.073-206.469-119.2034c-6.63-3.8287-14.811-3.8287-21.441 0l-206.4586 119.2034c-5.5734 3.218-9.0144 9.169-9.0144 15.615v240.375c0 6.436 3.441 12.397 9.0144 15.615l206.4686 119.203c6.63 3.829 14.811 3.829 21.441 0l206.468-119.203c5.574-3.218 9.015-9.17 9.015-15.615v-240.375c0-6.436-3.441-12.397-9.015-15.615zm-12.969 25.25-199.316 345.223c-1.347 2.326-4.904 1.376-4.904-1.319v-226.048c0-4.517-2.414-8.695-6.33-10.963l-195.7577-113.019c-2.3263-1.347-1.3764-4.905 1.3182-4.905h398.6305c5.661 0 9.199 6.136 6.368 11.041h-.009z"
}

struct SVGPathParser {
    static func path(from source: String) -> CGPath {
        var parser = SVGPathParser(source)
        return parser.parse()
    }

    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var cx: CGFloat = 0
    private var cy: CGFloat = 0
    private var startX: CGFloat = 0
    private var startY: CGFloat = 0
    private var lastControlX: CGFloat = 0
    private var lastControlY: CGFloat = 0
    private var lastCommand: Character = "M"

    private init(_ source: String) {
        scalars = Array(source.unicodeScalars)
    }

    private mutating func parse() -> CGPath {
        let path = CGMutablePath()
        while let command = nextCommand() {
            let before = index
            apply(command, to: path)
            if index == before, command != "Z", command != "z" { break }
        }
        return path
    }

    private mutating func nextCommand() -> Character? {
        skipSeparators()
        guard index < scalars.count else { return nil }
        let scalar = scalars[index]
        if isCommand(scalar) {
            index += 1
            let command = Character(scalar)
            lastCommand = command
            return command
        }
        guard isNumberStart(scalar) else { return nil }
        switch lastCommand {
        case "M": return "L"
        case "m": return "l"
        default: return lastCommand
        }
    }

    private mutating func apply(_ command: Character, to path: CGMutablePath) {
        switch command {
        case "M", "m":
            let relative = command == "m"
            let point = point(readNumber(), readNumber(), relative: relative)
            path.move(to: point)
            cx = point.x
            cy = point.y
            startX = point.x
            startY = point.y
            lastControlX = point.x
            lastControlY = point.y
            lastCommand = relative ? "l" : "L"
        case "L", "l":
            let point = point(readNumber(), readNumber(), relative: command == "l")
            path.addLine(to: point)
            moveCurrent(to: point)
        case "H", "h":
            let x = readNumber()
            cx = command == "h" ? cx + x : x
            let point = CGPoint(x: cx, y: cy)
            path.addLine(to: point)
            moveCurrent(to: point)
        case "V", "v":
            let y = readNumber()
            cy = command == "v" ? cy + y : y
            let point = CGPoint(x: cx, y: cy)
            path.addLine(to: point)
            moveCurrent(to: point)
        case "C", "c":
            let relative = command == "c"
            let control1 = point(readNumber(), readNumber(), relative: relative)
            let control2 = point(readNumber(), readNumber(), relative: relative)
            let end = point(readNumber(), readNumber(), relative: relative)
            path.addCurve(to: end, control1: control1, control2: control2)
            lastControlX = control2.x
            lastControlY = control2.y
            cx = end.x
            cy = end.y
        case "A", "a":
            let rx = abs(readNumber())
            let ry = abs(readNumber())
            let angle = readNumber()
            let large = readFlag()
            let sweep = readFlag()
            let end = point(readNumber(), readNumber(), relative: command == "a")
            appendArc(to: path, end: end, rx: rx, ry: ry, angle: angle, large: large, sweep: sweep)
            moveCurrent(to: end)
        case "Z", "z":
            path.closeSubpath()
            cx = startX
            cy = startY
            lastControlX = cx
            lastControlY = cy
        default:
            break
        }
    }

    private func point(_ x: CGFloat, _ y: CGFloat, relative: Bool) -> CGPoint {
        CGPoint(x: relative ? cx + x : x, y: relative ? cy + y : y)
    }

    private mutating func moveCurrent(to point: CGPoint) {
        cx = point.x
        cy = point.y
        lastControlX = point.x
        lastControlY = point.y
    }

    private mutating func appendArc(
        to path: CGMutablePath,
        end: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        angle: CGFloat,
        large: Bool,
        sweep: Bool
    ) {
        let x1 = cx
        let y1 = cy
        if rx == 0 || ry == 0 || (x1 == end.x && y1 == end.y) {
            path.addLine(to: end)
            return
        }
        let phi = angle * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx = (x1 - end.x) / 2
        let dy = (y1 - end.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy
        var radiusX = rx
        var radiusY = ry
        let lambda = (x1p * x1p) / (radiusX * radiusX) + (y1p * y1p) / (radiusY * radiusY)
        if lambda > 1 {
            let fix = sqrt(lambda)
            radiusX *= fix
            radiusY *= fix
        }
        let sign: CGFloat = (large == sweep) ? -1 : 1
        let numerator = max(0, radiusX * radiusX * radiusY * radiusY - radiusX * radiusX * y1p * y1p - radiusY * radiusY * x1p * x1p)
        let denominator = radiusX * radiusX * y1p * y1p + radiusY * radiusY * x1p * x1p
        let coef = sign * sqrt(denominator == 0 ? 0 : numerator / denominator)
        let cxp = coef * radiusX * y1p / radiusY
        let cyp = coef * -radiusY * x1p / radiusX
        let centerX = cosPhi * cxp - sinPhi * cyp + (x1 + end.x) / 2
        let centerY = sinPhi * cxp + cosPhi * cyp + (y1 + end.y) / 2
        let theta1 = vectorAngle(ux: 1, uy: 0, vx: (x1p - cxp) / radiusX, vy: (y1p - cyp) / radiusY)
        var delta = vectorAngle(
            ux: (x1p - cxp) / radiusX,
            uy: (y1p - cyp) / radiusY,
            vx: (-x1p - cxp) / radiusX,
            vy: (-y1p - cyp) / radiusY
        )
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2) - 1e-6)))
        let step = delta / CGFloat(segments)
        var theta = theta1
        for _ in 0..<segments {
            let next = theta + step
            addArcSegment(
                to: path,
                centerX: centerX,
                centerY: centerY,
                radiusX: radiusX,
                radiusY: radiusY,
                phi: phi,
                from: theta,
                to: next
            )
            theta = next
        }
    }

    private func addArcSegment(
        to path: CGMutablePath,
        centerX: CGFloat,
        centerY: CGFloat,
        radiusX: CGFloat,
        radiusY: CGFloat,
        phi: CGFloat,
        from start: CGFloat,
        to end: CGFloat
    ) {
        let k = 4 / 3 * tan((end - start) / 4)
        func map(_ theta: CGFloat) -> CGPoint {
            CGPoint(
                x: cos(phi) * radiusX * cos(theta) - sin(phi) * radiusY * sin(theta) + centerX,
                y: sin(phi) * radiusX * cos(theta) + cos(phi) * radiusY * sin(theta) + centerY
            )
        }
        func derivative(_ theta: CGFloat) -> CGPoint {
            CGPoint(
                x: -cos(phi) * radiusX * sin(theta) - sin(phi) * radiusY * cos(theta),
                y: -sin(phi) * radiusX * sin(theta) + cos(phi) * radiusY * cos(theta)
            )
        }
        let p1 = map(start)
        let p2 = map(end)
        let d1 = derivative(start)
        let d2 = derivative(end)
        path.addCurve(
            to: p2,
            control1: CGPoint(x: p1.x + k * d1.x, y: p1.y + k * d1.y),
            control2: CGPoint(x: p2.x - k * d2.x, y: p2.y - k * d2.y)
        )
    }

    private func vectorAngle(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat) -> CGFloat {
        atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    }

    private mutating func readNumber() -> CGFloat {
        skipSeparators()
        let start = index
        if peek("+") || peek("-") { index += 1 }
        var sawDigit = false
        var sawDot = false
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar >= "0", scalar <= "9" {
                sawDigit = true
                index += 1
            } else if scalar == ".", !sawDot {
                sawDot = true
                index += 1
            } else {
                break
            }
        }
        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            let exponent = index
            index += 1
            if peek("+") || peek("-") { index += 1 }
            var sawExponentDigit = false
            while index < scalars.count, scalars[index] >= "0", scalars[index] <= "9" {
                sawExponentDigit = true
                index += 1
            }
            if !sawExponentDigit { index = exponent }
        }
        guard sawDigit, start < index else { return 0 }
        let token = String(String.UnicodeScalarView(scalars[start..<index]))
        return CGFloat(Double(token) ?? 0)
    }

    private mutating func readFlag() -> Bool {
        skipSeparators()
        guard index < scalars.count else { return false }
        let scalar = scalars[index]
        guard scalar == "0" || scalar == "1" else { return false }
        index += 1
        return scalar == "1"
    }

    private mutating func skipSeparators() {
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == " " || scalar == "," || scalar == "\n" || scalar == "\r" || scalar == "\t" {
                index += 1
            } else {
                break
            }
        }
    }

    private func peek(_ value: Unicode.Scalar) -> Bool {
        index < scalars.count && scalars[index] == value
    }

    private func isCommand(_ scalar: Unicode.Scalar) -> Bool {
        switch Character(scalar) {
        case "M", "m", "L", "l", "H", "h", "V", "v", "C", "c", "Z", "z", "A", "a":
            true
        default:
            false
        }
    }

    private func isNumberStart(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "+" || scalar == "-" || scalar == "." || (scalar >= "0" && scalar <= "9")
    }
}

@MainActor
enum ProviderMarkImage {
    static func makeImage(for provider: ProviderID, side: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            draw(provider, in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = provider.displayName
        return image
    }

    static func draw(_ provider: ProviderID, in rect: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let path = ProviderGlyph.fittedPath(for: provider, in: rect)
        context.addPath(path)
        context.setFillColor(NSColor.black.cgColor)
        if ProviderGlyph.usesEvenOddFill(provider) {
            context.drawPath(using: .eoFill)
        } else {
            context.drawPath(using: .fill)
        }
    }
}

struct ProviderMark: View {
    var provider: ProviderID

    var body: some View {
        ProviderGlyphShape(provider: provider)
            .fill(.primary, style: FillStyle(eoFill: ProviderGlyph.usesEvenOddFill(provider)))
    }
}

private struct ProviderGlyphShape: Shape {
    var provider: ProviderID

    func path(in rect: CGRect) -> Path {
        Path(ProviderGlyph.fittedPath(for: provider, in: rect))
    }
}
