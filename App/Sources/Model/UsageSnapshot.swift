import Foundation

struct UsageSnapshot: Equatable, Sendable {
    var provider: ProviderID
    var fetchedAt: Date
    var meters: [Meter]
    var breakdown: Breakdown?
    var menuBarFraction: Double?
    /// Informational copy when the account has no meter to draw, such as a missing Grok allowance.
    var note: String?

    init(
        provider: ProviderID,
        fetchedAt: Date,
        meters: [Meter],
        breakdown: Breakdown? = nil,
        menuBarFraction: Double? = nil,
        note: String? = nil
    ) {
        self.provider = provider
        self.fetchedAt = fetchedAt
        self.meters = meters
        self.breakdown = breakdown
        self.menuBarFraction = menuBarFraction
        self.note = note
    }
}
