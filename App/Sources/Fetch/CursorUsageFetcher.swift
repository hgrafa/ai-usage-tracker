import Foundation

enum CursorDashboardRequests {
    static let periodUsage = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!
    static let sandUsage = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus")!

    static func request(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        return request
    }
}

enum CursorUsageMapping {
    static func snapshot(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let root = JSONFields.decodeObject(data) else {
            throw UsageFetchError.malformed
        }
        let plan = JSONFields.dictionary(root["planUsage"]) ?? [:]
        let spend = JSONFields.dictionary(root["spendLimitUsage"])
        let resetsAt = JSONFields.date(from: root["billingCycleEnd"])

        // Pro+ and the other current plans expose two included pools as percents
        // (Cursor models and other models). includedSpend is the plan's dollar
        // credit — $70 on Pro+, which costs $60/mo — and the spending page does
        // not show it. displayMessage can say the limit is hit while those pools
        // are nearly empty, so neither belongs next to the percent meters.
        if JSONFields.double(plan["autoPercentUsed"]) != nil || JSONFields.double(plan["apiPercentUsed"]) != nil {
            return percentSnapshot(plan: plan, resetsAt: resetsAt, fetchedAt: fetchedAt)
        }
        return dollarSnapshot(plan: plan, spend: spend, resetsAt: resetsAt, fetchedAt: fetchedAt)
    }

    private static func percentSnapshot(plan: [String: Any], resetsAt: Date?, fetchedAt: Date) -> UsageSnapshot {
        var meters: [Meter] = []
        var percents: [Double] = []
        if let auto = JSONFields.double(plan["autoPercentUsed"]) {
            percents.append(auto)
            meters.append(percentMeter(id: "cursor-models", title: "Cursor models", percent: auto, resetsAt: resetsAt, now: fetchedAt))
        }
        if let api = JSONFields.double(plan["apiPercentUsed"]) {
            percents.append(api)
            meters.append(percentMeter(id: "other-models", title: "Other models", percent: api, resetsAt: resetsAt, now: fetchedAt))
        }
        return UsageSnapshot(
            provider: .cursor,
            fetchedAt: fetchedAt,
            meters: meters,
            menuBarFraction: percents.max().map(UsageFormatting.clampedFraction(percent:))
        )
    }

    /// Older responses have no percent pools. includedSpend is cents used and limit is the included credit, in cents.
    private static func dollarSnapshot(
        plan: [String: Any],
        spend: [String: Any]?,
        resetsAt: Date?,
        fetchedAt: Date
    ) -> UsageSnapshot {
        var meters: [Meter] = []
        var menu: Double?
        let includedCents = JSONFields.double(plan["includedSpend"]) ?? 0
        let limitCents = JSONFields.double(plan["limit"]) ?? 0
        if limitCents > 0 {
            let fraction = min(1, max(0, includedCents / limitCents))
            menu = fraction
            meters.append(Meter(
                id: "included",
                title: "Included",
                fraction: fraction,
                caption: dollarCaption(usedCents: includedCents, limitCents: limitCents, resetsAt: resetsAt, now: fetchedAt)
            ))
        }
        if let spend, let onDemandLimit = JSONFields.double(spend["individualLimit"]), onDemandLimit > 0 {
            let used = JSONFields.double(spend["individualUsed"]) ?? 0
            let fraction = min(1, max(0, used / onDemandLimit))
            if menu == nil { menu = fraction }
            meters.append(Meter(
                id: "on-demand",
                title: "On-demand",
                fraction: fraction,
                caption: dollarCaption(usedCents: used, limitCents: onDemandLimit, resetsAt: resetsAt, now: fetchedAt)
            ))
        }
        return UsageSnapshot(
            provider: .cursor,
            fetchedAt: fetchedAt,
            meters: meters,
            menuBarFraction: menu
        )
    }

    private static func percentMeter(id: String, title: String, percent: Double, resetsAt: Date?, now: Date) -> Meter {
        Meter(
            id: id,
            title: title,
            fraction: UsageFormatting.clampedFraction(percent: percent),
            caption: UsageFormatting.usedCaption(percent: percent, resetsAt: resetsAt, now: now)
        )
    }

    private static func dollarCaption(usedCents: Double, limitCents: Double, resetsAt: Date?, now: Date) -> String {
        var caption = "\(UsageFormatting.dollars(cents: usedCents)) of \(UsageFormatting.dollars(cents: limitCents))"
        if let resetsAt {
            caption += " · \(UsageFormatting.resetHint(resetsAt, now: now))"
        }
        return caption
    }
}

struct CursorUsageFetcher: UsageFetcher {
    var tokens: CursorAccessTokenProvider
    var http: URLSessionHTTPClient
    var now: @Sendable () -> Date = { Date() }

    func fetch() async throws -> UsageSnapshot {
        let token = try await tokens.bearerToken()
        let response = try await http.send(CursorDashboardRequests.request(url: CursorDashboardRequests.periodUsage, token: token))
        if let failure = HTTPFailureMapper.map(
            statusCode: response.statusCode,
            body: response.body,
            provider: .cursor,
            htmlMeansUnauthorized: false
        ) {
            throw failure
        }
        return try CursorUsageMapping.snapshot(from: response.body, fetchedAt: now())
    }
}
