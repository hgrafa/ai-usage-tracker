import Foundation

enum ClaudeRequests {
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    static let organizationsURL = URL(string: "https://claude.ai/api/organizations")!

    static func cookieHeader(from paste: String) -> String {
        var value = paste.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("cookie:") {
            value = String(value.dropFirst("cookie:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if value.contains("=") { return value }
        return "sessionKey=\(value)"
    }

    static func usageURL(orgID: String) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = orgID.addingPercentEncoding(withAllowedCharacters: allowed) ?? orgID
        var components = URLComponents()
        components.scheme = "https"
        components.host = "claude.ai"
        components.path = "/api/organizations/\(encoded)/usage"
        return components.url
    }

    static func make(url: URL, cookie: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        return request
    }
}

enum ClaudeUsageMapping {
    static let noChatOrganizationMessage = "No Claude organization with chat was found."
    private static let palette: [SegmentColor] = [.purple, .green, .orange, .mauve, .coral, .gray]

    static func organizationID(inCookie cookie: String) -> String? {
        let pattern = #"lastActiveOrg=([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(cookie.startIndex..., in: cookie)
        guard let match = regex.firstMatch(in: cookie, range: range),
              let idRange = Range(match.range(at: 1), in: cookie)
        else { return nil }
        return String(cookie[idRange])
    }

    static func chatOrganizationID(from organizationsJSON: Data) throws -> String {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: organizationsJSON)
        } catch {
            throw UsageFetchError.malformed
        }
        let list: [Any]
        if let array = json as? [Any] {
            list = array
        } else if let object = json as? [String: Any], let array = object["organizations"] as? [Any] {
            list = array
        } else {
            throw UsageFetchError.malformed
        }
        for item in list {
            guard let org = item as? [String: Any] else { continue }
            let capabilities = (org["capabilities"] as? [Any])?.compactMap { $0 as? String } ?? []
            let hasChat = capabilities.contains { $0.caseInsensitiveCompare("chat") == .orderedSame }
            guard hasChat else { continue }
            if let uuid = JSONFields.string(org["uuid"]) { return uuid }
            if let id = JSONFields.string(org["id"]) { return id }
        }
        throw UsageFetchError.message(noChatOrganizationMessage)
    }

    static func snapshot(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let object = JSONFields.decodeObject(data) else {
            throw UsageFetchError.malformed
        }
        let known = ["five_hour", "seven_day", "limits"]
        if known.allSatisfy({ object[$0] == nil }) {
            throw UsageFetchError.malformed
        }

        var meters: [Meter] = []
        var percents: [Double] = []
        if let window = JSONFields.dictionary(object["five_hour"]),
           let utilization = JSONFields.double(window["utilization"]) {
            percents.append(utilization)
            meters.append(meter(id: "session", title: "Session (5 hour)", utilization: utilization, resets: window["resets_at"], now: fetchedAt))
        }
        if let window = JSONFields.dictionary(object["seven_day"]),
           let utilization = JSONFields.double(window["utilization"]) {
            percents.append(utilization)
            meters.append(meter(id: "weekly", title: "Weekly (7 day)", utilization: utilization, resets: window["resets_at"], now: fetchedAt))
        }
        let segments = weeklySegments(from: object["limits"])
        let breakdown = segments.isEmpty ? nil : Breakdown(headline: nil, total: nil, segments: segments)
        if meters.isEmpty, breakdown == nil {
            throw UsageFetchError.malformed
        }
        return UsageSnapshot(
            provider: .claude,
            fetchedAt: fetchedAt,
            meters: meters,
            breakdown: breakdown,
            menuBarFraction: percents.max().map { UsageFormatting.clampedFraction(percent: $0) }
        )
    }

    private static func meter(id: String, title: String, utilization: Double, resets: Any?, now: Date) -> Meter {
        Meter(
            id: id,
            title: title,
            fraction: UsageFormatting.clampedFraction(percent: utilization),
            caption: UsageFormatting.usedCaption(
                percent: utilization,
                resetsAt: JSONFields.date(from: resets),
                now: now
            )
        )
    }

    private static func weeklySegments(from value: Any?) -> [UsageSegment] {
        guard let items = value as? [Any] else { return [] }
        var segments: [UsageSegment] = []
        for item in items {
            guard let object = item as? [String: Any] else { continue }
            guard let type = JSONFields.string(object["type"])?.lowercased(),
                  type == "weekly_scoped" || type.contains("weekly_scoped")
            else { continue }
            guard let name = displayName(in: object) else { continue }
            guard let percent = JSONFields.double(object["utilization"]) ?? JSONFields.double(object["percent"]) else { continue }
            let index = segments.count
            segments.append(UsageSegment(
                id: "limit-\(index)",
                title: name,
                amount: percent,
                displayValue: "\(Int(percent.rounded()))%",
                color: palette[index % palette.count]
            ))
        }
        return segments
    }

    private static func displayName(in object: [String: Any]) -> String? {
        if let name = JSONFields.string(object["display_name"]) ?? JSONFields.string(object["displayName"]) ?? JSONFields.string(object["name"]) {
            return name
        }
        if let scope = object["scope"] as? [String: Any] {
            return JSONFields.string(scope["display_name"])
                ?? JSONFields.string(scope["displayName"])
                ?? JSONFields.string(scope["model"])
        }
        if let scope = JSONFields.string(object["scope"]) { return scope }
        return JSONFields.string(object["model"])
    }
}

struct ClaudeUsageFetcher: UsageFetcher {
    var store: KeychainCredentialStore
    var http: URLSessionHTTPClient
    var now: @Sendable () -> Date = { Date() }

    func fetch() async throws -> UsageSnapshot {
        let credential: Credential
        do {
            guard let stored = try store.load(provider: .claude) else {
                throw UsageFetchError.notConfigured
            }
            credential = stored
        } catch let error as UsageFetchError {
            throw error
        } catch {
            throw UsageFetchError.message("The saved Claude session could not be read.")
        }

        let cookie = ClaudeRequests.cookieHeader(from: credential.secret)
        let orgID: String
        if let existing = ClaudeUsageMapping.organizationID(inCookie: cookie) {
            orgID = existing
        } else {
            let response = try await http.send(ClaudeRequests.make(url: ClaudeRequests.organizationsURL, cookie: cookie))
            if let failure = HTTPFailureMapper.map(
                statusCode: response.statusCode,
                body: response.body,
                provider: .claude,
                htmlMeansUnauthorized: true
            ) {
                throw failure
            }
            orgID = try ClaudeUsageMapping.chatOrganizationID(from: response.body)
        }

        guard let usageURL = ClaudeRequests.usageURL(orgID: orgID) else {
            throw UsageFetchError.malformed
        }
        let usage = try await http.send(ClaudeRequests.make(url: usageURL, cookie: cookie))
        if let failure = HTTPFailureMapper.map(
            statusCode: usage.statusCode,
            body: usage.body,
            provider: .claude,
            htmlMeansUnauthorized: true
        ) {
            throw failure
        }
        return try ClaudeUsageMapping.snapshot(from: usage.body, fetchedAt: now())
    }
}
