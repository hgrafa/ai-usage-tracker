import AppKit

struct MenuBarReading: Equatable {
    var provider: ProviderID
    var percent: Int?
}

@MainActor
enum MenuBarTitle {
    /// One image already in the menu bar's text color. A template image would let the menu bar tint it,
    /// but on an inactive display macOS dims template images well below its own status icons.
    static func statusImage(for readings: [MenuBarReading], color: NSColor) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let iconSide: CGFloat = 18
        let sidePad: CGFloat = 6
        let iconTextGap: CGFloat = 6
        let groupGap: CGFloat = 16
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let labels = readings.isEmpty ? ["AI"] : readings.map { MenuBarLabel.valueTitle(percent: $0.percent) }
        let textSizes = labels.map { ($0 as NSString).size(withAttributes: textAttributes) }
        let textHeight = textSizes.map(\.height).max() ?? iconSide
        let height = max(iconSide, textHeight)
        var width = sidePad * 2 + CGFloat(readings.isEmpty ? 1 : readings.count) * iconSide
        width += textSizes.reduce(0) { $0 + iconTextGap + $1.width }
        if readings.count > 1 {
            width += CGFloat(readings.count - 1) * groupGap
        }
        let size = NSSize(width: max(width, 16), height: height)
        let image = NSImage(size: size, flipped: true) { bounds in
            var x = sidePad
            if readings.isEmpty {
                if let symbol = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "AI") {
                    let rect = NSRect(x: 0, y: (height - iconSide) / 2, width: iconSide, height: iconSide)
                    symbol.draw(in: rect)
                }
            }
            for (index, reading) in readings.enumerated() {
                let iconRect = NSRect(x: x, y: (height - iconSide) / 2, width: iconSide, height: iconSide)
                ProviderMarkImage.draw(reading.provider, in: iconRect)
                x += iconSide + iconTextGap
                let text = labels[index] as NSString
                let textSize = textSizes[index]
                text.draw(
                    at: NSPoint(x: x, y: (height - textSize.height) / 2),
                    withAttributes: textAttributes
                )
                x += textSize.width
                if index < readings.count - 1 {
                    x += groupGap
                }
            }
            // Everything above is drawn black; recolor it in one pass.
            color.set()
            bounds.fill(using: .sourceAtop)
            return true
        }
        image.accessibilityDescription = readings.map(MenuBarLabel.itemLabel).joined(separator: ", ")
        return image
    }

    /// The menu bar's text color for an appearance: white on a dark bar, black on a light one.
    static func textColor(for appearance: NSAppearance) -> NSColor {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .white : .black
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
