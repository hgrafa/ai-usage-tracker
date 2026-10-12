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

        var meters: [Meter] = []
        var percents: [Double] = []
        if let auto = JSONFields.double(plan["autoPercentUsed"]) {
            percents.append(auto)
            meters.append(percentMeter(id: "cursor-models", title: "Cursor models", percent: auto))
        }
        if let api = JSONFields.double(plan["apiPercentUsed"]) {
            percents.append(api)
            meters.append(percentMeter(id: "other-models", title: "Other models", percent: api))
        }

        var includedFraction: Double?
        if percents.isEmpty,
           let limit = JSONFields.double(plan["limit"]),
           let included = JSONFields.double(plan["includedSpend"]),
           limit > 0 {
            let fraction = min(1, max(0, included / limit))
            includedFraction = fraction
            meters.append(Meter(
                id: "included",
                title: "Included",
                fraction: fraction,
                caption: UsageFormatting.usedCaption(percent: fraction * 100, resetsAt: nil, now: fetchedAt)
            ))
        }

        let menu: Double?
        if let maxPercent = percents.max() {
            menu = UsageFormatting.clampedFraction(percent: maxPercent)
        } else {
            menu = includedFraction
        }

        return UsageSnapshot(
            provider: .cursor,
            fetchedAt: fetchedAt,
            meters: meters,
            breakdown: breakdown(plan: plan, spend: spend, headline: JSONFields.string(root["displayMessage"])),
            menuBarFraction: menu
        )
    }

    private static func percentMeter(id: String, title: String, percent: Double) -> Meter {
        Meter(
            id: id,
            title: title,
            fraction: UsageFormatting.clampedFraction(percent: percent),
            caption: UsageFormatting.usedCaption(percent: percent, resetsAt: nil, now: Date())
        )
    }

    private static func breakdown(plan: [String: Any], spend: [String: Any]?, headline: String?) -> Breakdown? {
        var segments: [UsageSegment] = []
        if let includedCents = JSONFields.double(plan["includedSpend"]) {
            segments.append(UsageSegment(
                id: "included-spend",
                title: "Included",
                amount: includedCents / 100,
                displayValue: UsageFormatting.dollars(cents: includedCents),
                color: .green
            ))
        }
        if let spend, let onDemandCents = JSONFields.double(spend["individualUsed"]) {
            segments.append(UsageSegment(
                id: "on-demand",
                title: "On-demand",
                amount: onDemandCents / 100,
                displayValue: UsageFormatting.dollars(cents: onDemandCents),
                color: .purple
            ))
        }
        if !segments.contains(where: { $0.amount != 0 }) {
            segments = []
        }
        let trimmedHeadline = headline?.trimmingCharacters(in: .whitespacesAndNewlines)
        let headlineText = (trimmedHeadline?.isEmpty == false) ? trimmedHeadline : nil
        if segments.isEmpty, headlineText == nil { return nil }
        return Breakdown(headline: headlineText, total: nil, segments: segments)
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
