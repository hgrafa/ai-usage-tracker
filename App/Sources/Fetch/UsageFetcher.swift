import Foundation

protocol UsageFetcher: Sendable {
    func fetch() async throws -> UsageSnapshot
}
