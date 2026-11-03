import SwiftUI

struct MeterRow: View {
    let meter: Meter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meter.title)
                .font(.subheadline.weight(.medium))
            GeometryReader { geometry in
                MeterTrack(fraction: meter.fraction, width: geometry.size.width)
            }
            .frame(height: Theme.knobSize)
            Text(meter.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .geometryGroup()
    }
}

private struct MeterTrack: View {
    var fraction: Double?
    var width: CGFloat

    var body: some View {
        let clamped = min(1, max(0, fraction ?? 0))
        let color = fraction == nil ? Color.primary.opacity(0.45) : Theme.heatColor(for: clamped)
        let travel = max(0, width - Theme.knobSize)
        let origin = travel * clamped
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.16))
                .frame(height: Theme.meterTrackHeight)
            Capsule()
                .fill(color)
                .frame(width: max(0, origin), height: Theme.meterTrackHeight)
            Circle()
                .fill(color)
                .frame(width: Theme.knobSize, height: Theme.knobSize)
                .offset(x: origin)
        }
        .frame(height: Theme.knobSize)
    }
}
