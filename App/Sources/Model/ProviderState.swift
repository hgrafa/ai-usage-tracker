import Foundation

enum ProviderPhase: Equatable, Sendable {
    case unconfigured
    case loading(stale: UsageSnapshot?)
    case loaded(UsageSnapshot)
    case failed(message: String, stale: UsageSnapshot?)
}
