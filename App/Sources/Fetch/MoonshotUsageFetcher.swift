import Foundation

enum MoonshotUsageMapping {
    // shortcut: international then China, add a host when Moonshot documents another region
    static let balanceURLs = [
        URL(string: "https://api.moonshot.ai/v1/users/me/balance")!,
        URL(string: "https://api.moonshot.cn/v1/users/me/balance")!
    ]

    static func currency(for url: URL) -> String {
        url.host == "api.moonshot.cn" ? "CNY" : "USD"
    }

    static func snapshot(from data: Data, currency: String, fetchedAt: Date) throws -> UsageSnapshot {
        guard let object = JSONFields.decodeObject(data),
              JSONFields.double(object["code"]) == 0,
              let payload = JSONFields.dictionary(object["data"]),
              let available = JSONFields.double(payload["available_balance"])
        else { throw UsageFetchError.malformed }

        var parts = ["\(UsageFormatting.money(available, currency: currency)) available"]
        if let cash = JSONFields.double(payload["cash_balance"]) {
            if cash < 0 {
                parts.append("owes \(UsageFormatting.money(-cash, currency: currency))")
            } else if cash > 0 {
                parts.append("\(UsageFormatting.money(cash, currency: currency)) cash")
            }
        }
        if let voucher = JSONFields.double(payload["voucher_balance"]), voucher > 0 {
            parts.append("\(UsageFormatting.money(voucher, currency: currency)) voucher")
        }
        if available <= 0 {
            parts.append("add credits to call the API")
        }
        return UsageSnapshot(
            provider: .moonshot,
            fetchedAt: fetchedAt,
            meters: [],
            menuBarFraction: nil,
            note: parts.joined(separator: " · ")
        )
    }
}

struct MoonshotUsageFetcher: UsageFetcher {
    var store: KeychainCredentialStore
    var http: URLSessionHTTPClient

    func fetch() async throws -> UsageSnapshot {
        let token = try APIKeyRequests.token(for: .moonshot, store: store)
        var sawUnauthorized = false
        for url in MoonshotUsageMapping.balanceURLs {
            do {
                let body = try await APIKeyRequests.get(url, token: token, provider: .moonshot, http: http)
                return try MoonshotUsageMapping.snapshot(
                    from: body,
                    currency: MoonshotUsageMapping.currency(for: url),
                    fetchedAt: Date()
                )
            } catch let error as UsageFetchError where error == .unauthorized(.moonshot) {
                sawUnauthorized = true
            }
        }
        throw sawUnauthorized ? UsageFetchError.unauthorized(.moonshot) : UsageFetchError.network
    }
}
