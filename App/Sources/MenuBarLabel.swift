import SwiftUI

struct MenuBarLabel: View {
    var percent: Int?

    var body: some View {
        if let title = Self.title(percent: percent) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .accessibilityLabel("\(title) used")
        } else {
            Image(systemName: "gauge.medium")
                .font(.system(size: 14, weight: .regular))
                .accessibilityLabel("AI usage")
        }
    }

    static func title(percent: Int?) -> String? {
        guard let percent else { return nil }
        return "\(percent)%"
    }
}

enum MenuBarMath {
    static func percent(from snapshots: [UsageSnapshot]) -> Int? {
        let fractions = snapshots.compactMap(\.menuBarFraction)
        guard let maxFraction = fractions.max() else { return nil }
        let rounded = Int((maxFraction * 100).rounded())
        return min(100, max(0, rounded))
    }

    static func percent(from phases: [ProviderID: ProviderPhase]) -> Int? {
        percent(from: snapshots(from: phases))
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
