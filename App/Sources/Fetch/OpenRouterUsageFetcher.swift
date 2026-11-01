import Foundation

enum OpenRouterUsageMapping {
    static let keyURL = URL(string: "https://openrouter.ai/api/v1/key")!

    static func snapshot(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let object = JSONFields.decodeObject(data),
              let payload = JSONFields.dictionary(object["data"])
        else { throw UsageFetchError.malformed }

        var meters: [Meter] = []
        if let limit = JSONFields.double(payload["limit"]),
           limit > 0,
           let remaining = JSONFields.double(payload["limit_remaining"]) {
            let spent = limit - remaining
            var caption = "\(UsageFormatting.money(spent)) of \(UsageFormatting.money(limit))"
            if let reset = JSONFields.string(payload["limit_reset"]) {
                caption += " · \(reset)"
            }
            meters.append(Meter(id: "key-limit", title: "Key limit", fraction: fraction(spent, of: limit), caption: caption))
        }
        if let budget = JSONFields.dictionary(payload["effective_budget"]),
           let limit = JSONFields.double(budget["limit_usd"]),
           limit > 0,
           let spent = JSONFields.double(budget["spend_usd"]) {
            var caption = "\(UsageFormatting.money(spent)) of \(UsageFormatting.money(limit))"
            if let reset = JSONFields.string(budget["reset_interval"]) {
                caption += " · \(reset)"
            }
            meters.append(Meter(id: "budget", title: "Budget", fraction: fraction(spent, of: limit), caption: caption))
        }
        if let free = JSONFields.dictionary(payload["free_model_daily_requests"]),
           let limit = JSONFields.double(free["limit"]),
           limit > 0 {
            let used = JSONFields.double(free["used"])
                ?? JSONFields.double(free["remaining"]).map { limit - $0 }
            if let used {
                meters.append(Meter(
                    id: "free-models",
                    title: "Free models",
                    fraction: fraction(used, of: limit),
                    caption: "\(Int(used.rounded())) of \(Int(limit.rounded())) today"
                ))
            }
        }

        let note = meters.isEmpty ? spendNote(payload) : nil
        return UsageSnapshot(
            provider: .openrouter,
            fetchedAt: fetchedAt,
            meters: meters,
            menuBarFraction: meters.compactMap(\.fraction).max(),
            note: note
        )
    }

    private static func fraction(_ spent: Double, of limit: Double) -> Double {
        min(1, max(0, spent / limit))
    }

    private static func spendNote(_ payload: [String: Any]) -> String {
        let parts = [
            JSONFields.double(payload["usage_daily"]).map { "\(UsageFormatting.money($0)) today" },
            JSONFields.double(payload["usage_weekly"]).map { "\(UsageFormatting.money($0)) this week" },
            JSONFields.double(payload["usage_monthly"]).map { "\(UsageFormatting.money($0)) this month" }
        ].compactMap { $0 }
        if parts.isEmpty { return "No spend cap on this key." }
        return "No spend cap. " + parts.joined(separator: " · ")
    }
}

struct OpenRouterUsageFetcher: UsageFetcher {
    var store: KeychainCredentialStore
    var http: URLSessionHTTPClient

    func fetch() async throws -> UsageSnapshot {
        let token = try APIKeyRequests.token(for: .openrouter, store: store)
        let body = try await APIKeyRequests.get(OpenRouterUsageMapping.keyURL, token: token, provider: .openrouter, http: http)
        return try OpenRouterUsageMapping.snapshot(from: body, fetchedAt: Date())
    }
}
