import Foundation

enum GrokUsageMapping {
    static let noAllowanceMessage = "No Grok Bot allowance on this account."

    static func snapshot(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let object = JSONFields.decodeObject(data) else {
            throw UsageFetchError.malformed
        }
        if JSONFields.bool(object["hasNonZeroIncludedLimit"]) == false {
            return UsageSnapshot(
                provider: .grok,
                fetchedAt: fetchedAt,
                meters: [],
                menuBarFraction: nil,
                note: noAllowanceMessage
            )
        }
        let pooled = JSONFields.bool(object["usesPooledEnterpriseAllowance"]) == true
        guard !pooled, let percent = JSONFields.double(object["usagePercent"]) else {
            return UsageSnapshot(provider: .grok, fetchedAt: fetchedAt, meters: [], menuBarFraction: nil)
        }
        let fraction = UsageFormatting.clampedFraction(percent: percent)
        let reset = JSONFields.date(from: object["nextResetTimestampUtc"], milliseconds: true)
        return UsageSnapshot(
            provider: .grok,
            fetchedAt: fetchedAt,
            meters: [
                Meter(
                    id: "weekly",
                    title: "Weekly",
                    fraction: fraction,
                    caption: UsageFormatting.usedCaption(percent: percent, resetsAt: reset, now: fetchedAt)
                )
            ],
            menuBarFraction: fraction
        )
    }
}

struct GrokUsageFetcher: UsageFetcher {
    var tokens: CursorAccessTokenProvider
    var http: URLSessionHTTPClient

    func fetch() async throws -> UsageSnapshot {
        let token = try await tokens.bearerToken()
        let response = try await http.send(CursorDashboardRequests.request(url: CursorDashboardRequests.sandUsage, token: token))
        if let failure = HTTPFailureMapper.map(
            statusCode: response.statusCode,
            body: response.body,
            provider: .grok,
            htmlMeansUnauthorized: false
        ) {
            throw failure
        }
        return try GrokUsageMapping.snapshot(from: response.body, fetchedAt: Date())
    }
}
