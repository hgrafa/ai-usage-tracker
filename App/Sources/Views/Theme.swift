import SwiftUI

enum Theme {
    static let popoverWidth: CGFloat = 320
    static let padding: CGFloat = 16
    static let meterTrackHeight: CGFloat = 4
    static let knobSize: CGFloat = 10
    static let breakdownBarHeight: CGFloat = 8
    static let background = Color(red: 0.11, green: 0.11, blue: 0.12)

    static func heatColor(for fraction: Double) -> Color {
        switch MeterHeat.level(for: fraction) {
        case .low: .white
        case .warm: .orange
        case .hot: .red
        }
    }

    static func segmentColor(_ color: SegmentColor) -> Color {
        switch color {
        case .gray: Color(white: 0.62)
        case .purple: Color(red: 0.64, green: 0.52, blue: 0.98)
        case .green: Color(red: 0.36, green: 0.80, blue: 0.48)
        case .orange: Color(red: 0.98, green: 0.62, blue: 0.25)
        case .mauve: Color(red: 0.78, green: 0.55, blue: 0.72)
        case .coral: Color(red: 0.98, green: 0.48, blue: 0.42)
        }
    }
}
