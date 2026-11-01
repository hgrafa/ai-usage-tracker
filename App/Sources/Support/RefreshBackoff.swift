import Foundation

/// A provider that answers "too many requests" sits out refreshes for a while, keeping what it last showed.
struct RefreshBackoff: Equatable, Sendable {
    static let wait: TimeInterval = 10 * 60

    private var limitedAt: [ProviderID: Date] = [:]

    mutating func record(_ provider: ProviderID, result: Result<UsageSnapshot, UsageFetchError>, at date: Date) {
        if case .failure(.rateLimited) = result {
            limitedAt[provider] = date
        } else {
            limitedAt[provider] = nil
        }
    }

    func isWaiting(_ provider: ProviderID, now: Date) -> Bool {
        guard let since = limitedAt[provider] else { return false }
        return now.timeIntervalSince(since) < Self.wait
    }
}
