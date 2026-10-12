import SwiftUI

struct BreakdownChart: View {
    let breakdown: Breakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let headline = breakdown.headline, !headline.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let total = breakdown.total, !total.isEmpty {
                        Text(total)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            if showsBar {
                GeometryReader { geometry in
                    let total = breakdown.segments.reduce(0) { $0 + max($1.amount, 0) }
                    HStack(spacing: 0) {
                        ForEach(breakdown.segments) { segment in
                            Theme.segmentColor(segment.color)
                                .frame(width: total > 0 ? geometry.size.width * max(segment.amount, 0) / total : 0)
                        }
                    }
                }
                .frame(height: Theme.breakdownBarHeight)
                .clipShape(Capsule())
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            ForEach(breakdown.segments) { segment in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.segmentColor(segment.color))
                        .frame(width: 10, height: 10)
                    Text(segment.title)
                    Spacer(minLength: 8)
                    Text(segment.displayValue)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    private var showsBar: Bool {
        breakdown.segments.contains { $0.amount > 0 }
    }
}
