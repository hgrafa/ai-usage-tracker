import Foundation

struct LimitAlert: Equatable, Sendable {
    var provider: ProviderID
    var meterID: String
    var meterTitle: String
    var caption: String
    var threshold: Int

    var title: String { "\(provider.displayName) at \(threshold)%" }
    var body: String { caption.isEmpty ? meterTitle : "\(meterTitle) · \(caption)" }
    var identifier: String { "\(provider.rawValue).\(meterID).\(threshold)" }
}

struct AlertThresholds: Equatable, Sendable {
    static let presets = [50, 75, 90, 100]

    var values: Set<Int>

    /// Missing storage means alerts are off.
    init(stored raw: [Int]?) {
        values = Set((raw ?? []).filter(Self.presets.contains))
    }

    var stored: [Int] {
        values.sorted()
    }
}

/// Remembers the highest threshold already announced for each meter, so each crossing notifies once
/// and the same threshold can notify again after the meter resets below it.
struct LimitAlertTracker: Equatable, Sendable {
    private(set) var announced: [String: Int]

    init(announced: [String: Int] = [:]) {
        self.announced = announced
    }

    mutating func alerts(for snapshot: UsageSnapshot, thresholds: Set<Int>) -> [LimitAlert] {
        var alerts: [LimitAlert] = []
        for meter in snapshot.meters {
            guard let fraction = meter.fraction else { continue }
            let key = "\(snapshot.provider.rawValue).\(meter.id)"
            let percent = MenuBarMath.roundedPercent(fraction)
            let reached = thresholds.filter { $0 <= percent }.max()
            if let reached, reached > announced[key] ?? 0 {
                alerts.append(LimitAlert(
                    provider: snapshot.provider,
                    meterID: meter.id,
                    meterTitle: meter.title,
                    caption: meter.caption,
                    threshold: reached
                ))
            }
            announced[key] = reached
        }
        return alerts
    }
}
