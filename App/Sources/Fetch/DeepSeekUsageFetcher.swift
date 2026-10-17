import Foundation

enum DeepSeekUsageMapping {
    static let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!

    static func snapshot(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let object = JSONFields.decodeObject(data),
              let raw = object["balance_infos"] as? [Any]
        else { throw UsageFetchError.malformed }
        let rows = raw.compactMap { $0 as? [String: Any] }
        guard let row = rows.first(where: { JSONFields.string($0["currency"])?.uppercased() == "USD" }) ?? rows.first,
              let total = JSONFields.double(row["total_balance"])
        else {
            return UsageSnapshot(provider: .deepseek, fetchedAt: fetchedAt, meters: [], note: "No balance reported.")
        }
        let currency = JSONFields.string(row["currency"]) ?? "USD"
        var parts = ["\(UsageFormatting.money(total, currency: currency)) remaining"]
        if let granted = JSONFields.double(row["granted_balance"]), granted > 0 {
            parts.append("\(UsageFormatting.money(granted, currency: currency)) granted")
        }
        if let toppedUp = JSONFields.double(row["topped_up_balance"]), toppedUp > 0 {
            parts.append("\(UsageFormatting.money(toppedUp, currency: currency)) topped up")
        }
        if JSONFields.bool(object["is_available"]) == false {
            parts.append("not usable for API calls")
        }
        return UsageSnapshot(
            provider: .deepseek,
            fetchedAt: fetchedAt,
            meters: [],
            menuBarFraction: nil,
            note: parts.joined(separator: " · ")
        )
    }
}

struct DeepSeekUsageFetcher: UsageFetcher {
    var store: KeychainCredentialStore
    var http: URLSessionHTTPClient

    func fetch() async throws -> UsageSnapshot {
        let token = try APIKeyRequests.token(for: .deepseek, store: store)
        let body = try await APIKeyRequests.get(DeepSeekUsageMapping.balanceURL, token: token, provider: .deepseek, http: http)
        return try DeepSeekUsageMapping.snapshot(from: body, fetchedAt: Date())
    }
}
