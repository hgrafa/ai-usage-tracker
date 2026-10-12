import Foundation

struct Meter: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var fraction: Double?
    var caption: String
}

enum SegmentColor: String, Equatable, Sendable {
    case gray
    case purple
    case green
    case orange
    case mauve
    case coral
}

struct UsageSegment: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var amount: Double
    var displayValue: String
    var color: SegmentColor
}

struct Breakdown: Equatable, Sendable {
    var headline: String?
    var total: String?
    var segments: [UsageSegment]
}
