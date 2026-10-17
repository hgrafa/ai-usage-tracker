import Foundation

/// The Anthropic API row takes one pasted secret: an Admin API key for an organization,
/// or a Console session cookie for an individual account, which cannot make Admin keys.
enum AnthropicAPISecret: Equatable, Sendable {
    case adminKey(String)
    case consoleCookie(String)
    case regularAPIKey

    static let regularKeyMessage = "That is a regular API key. Paste an Admin API key (sk-ant-admin…) or a Console cookie."

    init(paste: String) {
        var value = paste.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("bearer ") {
            value = String(value.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if value.hasPrefix("sk-ant-admin") {
            self = .adminKey(value)
        } else if value.hasPrefix("sk-ant-api") {
            self = .regularAPIKey
        } else {
            self = .consoleCookie(ClaudeRequests.cookieHeader(from: value))
        }
    }
}

enum AnthropicAPIRequests {
    static let costReportURL = URL(string: "https://api.anthropic.com/v1/organizations/cost_report")!
    static let consoleOrigin = "https://platform.claude.com"
    static let consoleOrganizationsURL = URL(string: "https://platform.claude.com/api/organizations")!

    /// Daily buckets from the first of this UTC month through the end of today.
    static func costReport(adminKey: String, now: Date, page: String?) -> URLRequest? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start,
              let tomorrow = calendar.dateInterval(of: .day, for: now)?.end
        else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var query = [
            ("starting_at", formatter.string(from: monthStart)),
            ("ending_at", formatter.string(from: tomorrow)),
            ("bucket_width", "1d"),
            ("limit", "31")
        ]
        if let page { query.append(("page", page)) }
        // Escape everything outside the unreserved set; a page cursor can carry "=" or "+".
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let encoded = query.map { name, value in
            "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value)"
        }
        guard let url = URL(string: "\(costReportURL.absoluteString)?\(encoded.joined(separator: "&"))") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(adminKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("AI-Usage", forHTTPHeaderField: "User-Agent")
        return request
    }

    static func consoleCreditsURL(orgID: String) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = orgID.addingPercentEncoding(withAllowedCharacters: allowed) ?? orgID
        return URL(string: "\(consoleOrigin)/api/organizations/\(encoded)/prepaid/credits")
    }

    static func console(url: URL, cookie: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(consoleOrigin, forHTTPHeaderField: "Origin")
        request.setValue(consoleOrigin, forHTTPHeaderField: "Referer")
        request.setValue(ClaudeRequests.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        return request
    }
}

enum AnthropicAPIUsageMapping {
    static let noOrganizationMessage = "No Console organization was found for that cookie."

    struct Spend: Equatable {
        var monthCents: Double
        var todayCents: Double
    }

    /// Cost report amounts are decimal strings in cents. Today is the bucket that contains `now`.
    static func spend(fromCostReports pages: [Data], now: Date) throws -> Spend {
        var spend = Spend(monthCents: 0, todayCents: 0)
        for page in pages {
            guard let object = JSONFields.decodeObject(page), let buckets = object["data"] as? [Any] else {
                throw UsageFetchError.malformed
            }
            for item in buckets {
                guard let bucket = item as? [String: Any] else { continue }
                let cents = (bucket["results"] as? [Any] ?? []).reduce(0.0) { total, result in
                    total + (JSONFields.double(JSONFields.dictionary(result)?["amount"]) ?? 0)
                }
                spend.monthCents += cents
                if let start = JSONFields.date(from: bucket["starting_at"]),
                   let end = JSONFields.date(from: bucket["ending_at"]),
                   start <= now, now < end {
                    spend.todayCents += cents
                }
            }
        }
        return spend
    }

    static func nextPage(in data: Data) -> String? {
        guard let object = JSONFields.decodeObject(data), JSONFields.bool(object["has_more"]) == true else { return nil }
        return JSONFields.string(object["next_page"])
    }

    static func snapshot(spend: Spend, fetchedAt: Date) -> UsageSnapshot {
        UsageSnapshot(
            provider: .anthropic,
            fetchedAt: fetchedAt,
            meters: [],
            menuBarFraction: nil,
            note: "\(UsageFormatting.dollars(cents: spend.monthCents)) spent this month · \(UsageFormatting.dollars(cents: spend.todayCents)) today"
        )
    }

    /// The cookie's last active org wins. Otherwise a Console org (the "api" capability), then any org.
    static func consoleOrganizationID(cookie: String, organizations: Data) throws -> String {
        if let orgID = ClaudeUsageMapping.organizationID(inCookie: cookie) { return orgID }
        guard let json = try? JSONSerialization.jsonObject(with: organizations) else { throw UsageFetchError.malformed }
        let list = (json as? [Any]) ?? (JSONFields.dictionary(json)?["organizations"] as? [Any]) ?? []
        let orgs = list.compactMap { $0 as? [String: Any] }
        let console = orgs.first { org in
            ((org["capabilities"] as? [Any]) ?? []).contains { (JSONFields.string($0) ?? "").lowercased().hasPrefix("api") }
        }
        guard let org = console ?? orgs.first,
              let id = JSONFields.string(org["uuid"]) ?? JSONFields.string(org["id"])
        else { throw UsageFetchError.message(noOrganizationMessage) }
        return id
    }

    /// Prepaid Console credits. `amount` is in cents.
    static func creditSnapshot(from data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let object = JSONFields.decodeObject(data), let cents = JSONFields.double(object["amount"]) else {
            throw UsageFetchError.malformed
        }
        let currency = JSONFields.string(object["currency"]) ?? "USD"
        var note = "\(UsageFormatting.money(cents / 100, currency: currency)) credit left"
        if JSONFields.bool(JSONFields.dictionary(object["auto_reload_settings"])?["enabled"]) == true {
            note += " · auto-reload on"
        }
        return UsageSnapshot(provider: .anthropic, fetchedAt: fetchedAt, meters: [], menuBarFraction: nil, note: note)
    }
}

struct AnthropicAPIUsageFetcher: UsageFetcher {
    /// A month has at most 31 daily buckets, so one page is normal. This only guards a runaway cursor.
    static let maxPages = 3

    var store: any CredentialStoring
    var http: any HTTPClient
    var now: @Sendable () -> Date = { Date() }

    func fetch() async throws -> UsageSnapshot {
        let secret: String
        do {
            guard let saved = try store.load(provider: .anthropic)?.secret else { throw UsageFetchError.notConfigured }
            secret = saved
        } catch let error as UsageFetchError {
            throw error
        } catch {
            throw UsageFetchError.message("The saved Anthropic key could not be read.")
        }
        let fetchedAt = now()
        switch AnthropicAPISecret(paste: secret) {
        case .adminKey(let key):
            return AnthropicAPIUsageMapping.snapshot(spend: try await monthSpend(adminKey: key, now: fetchedAt), fetchedAt: fetchedAt)
        case .consoleCookie(let cookie):
            return try await credits(cookie: cookie, fetchedAt: fetchedAt)
        case .regularAPIKey:
            throw UsageFetchError.message(AnthropicAPISecret.regularKeyMessage)
        }
    }

    private func monthSpend(adminKey: String, now: Date) async throws -> AnthropicAPIUsageMapping.Spend {
        var pages: [Data] = []
        var cursor: String?
        repeat {
            guard let request = AnthropicAPIRequests.costReport(adminKey: adminKey, now: now, page: cursor) else {
                throw UsageFetchError.malformed
            }
            let body = try await send(request, htmlMeansUnauthorized: false)
            pages.append(body)
            cursor = AnthropicAPIUsageMapping.nextPage(in: body)
        } while cursor != nil && pages.count < Self.maxPages
        return try AnthropicAPIUsageMapping.spend(fromCostReports: pages, now: now)
    }

    private func credits(cookie: String, fetchedAt: Date) async throws -> UsageSnapshot {
        let orgs = try await send(AnthropicAPIRequests.console(url: AnthropicAPIRequests.consoleOrganizationsURL, cookie: cookie), htmlMeansUnauthorized: true)
        let orgID = try AnthropicAPIUsageMapping.consoleOrganizationID(cookie: cookie, organizations: orgs)
        guard let url = AnthropicAPIRequests.consoleCreditsURL(orgID: orgID) else { throw UsageFetchError.malformed }
        let body = try await send(AnthropicAPIRequests.console(url: url, cookie: cookie), htmlMeansUnauthorized: true)
        return try AnthropicAPIUsageMapping.creditSnapshot(from: body, fetchedAt: fetchedAt)
    }

    private func send(_ request: URLRequest, htmlMeansUnauthorized: Bool) async throws -> Data {
        let response = try await http.send(request)
        if let failure = HTTPFailureMapper.map(
            statusCode: response.statusCode,
            body: response.body,
            provider: .anthropic,
            htmlMeansUnauthorized: htmlMeansUnauthorized
        ) {
            throw failure
        }
        return response.body
    }
}
