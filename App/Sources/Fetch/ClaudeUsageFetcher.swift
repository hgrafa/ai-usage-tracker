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

    static func usageURL(orgID: String, probe: String? = nil) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = orgID.addingPercentEncoding(withAllowedCharacters: allowed) ?? orgID
        var components = URLComponents()
        components.scheme = "https"
        components.host = "claude.ai"
        components.path = "/api/organizations/\(encoded)/usage"
        if let probe, !probe.isEmpty {
            components.percentEncodedQuery = probe
        }
        return components.url
    }

    static func prepaidCreditsURL(orgID: String) -> URL? {
        organizationURL(orgID: orgID, resource: "prepaid/credits")
    }

    static func overageURL(orgID: String) -> URL? {
        organizationURL(orgID: orgID, resource: "overage_spend_limit")
    }

    private static func organizationURL(orgID: String, resource: String) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = orgID.addingPercentEncoding(withAllowedCharacters: allowed) ?? orgID
        var components = URLComponents()
        components.scheme = "https"
        components.host = "claude.ai"
        components.path = "/api/organizations/\(encoded)/\(resource)"
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

    struct ResetRead: Equatable {
        var cedar: ResetInventory?
        var juniper: ResetInventory?
    }

    static func resetRead(from data: Data, now: Date) -> ResetRead {
        guard let object = JSONFields.decodeObject(data) else { return ResetRead() }
        var read = ResetRead()
        if let block = JSONFields.dictionary(object["cedar_ember"]) {
            read.cedar = cedarInventory(block, now: now)
        }
        if read.cedar == nil {
            for (key, value) in object where key != "juniper_tide" {
                guard let block = JSONFields.dictionary(value), block["grants"] != nil else { continue }
                read.cedar = cedarInventory(block, now: now)
                break
            }
        }
        if let block = JSONFields.dictionary(object["juniper_tide"]) {
            read.juniper = juniperInventory(block, now: now)
        }
        return read
    }

    static func inventory(combining read: ResetRead) -> ResetInventory? {
        var grants: [LimitReset] = []
        var evaluated = false
        for inventory in [read.cedar, read.juniper] {
            guard let inventory else { continue }
            evaluated = true
            if case .grants(let items) = inventory {
                grants.append(contentsOf: items)
            }
        }
        if !grants.isEmpty { return .grants(grants) }
        return evaluated ? ResetInventory.none : nil
    }

    private static func cedarInventory(_ block: [String: Any], now: Date) -> ResetInventory {
        let rawGrants = block["grants"] as? [Any] ?? []
        var grants: [LimitReset] = []
        for item in rawGrants {
            guard let grant = item as? [String: Any] else { continue }
            guard let remaining = wholeNumber(grant["resets_left"]), remaining > 0 else { continue }
            let expires = JSONFields.date(from: grant["ends_at"])
            if let expires, expires <= now { continue }
            let clears = (grant["clears"] as? [Any])?.compactMap { JSONFields.string($0) } ?? []
            let id = JSONFields.string(grant["id"]) ?? "cedar-\(grants.count)"
            grants.append(LimitReset(
                id: id,
                remaining: remaining,
                restores: restores(clears),
                expiresAt: expires,
                available: JSONFields.bool(grant["usable_now"]) ?? true
            ))
        }
        return grants.isEmpty ? .none : .grants(grants)
    }

    private static func juniperInventory(_ block: [String: Any], now: Date) -> ResetInventory {
        let eligible = JSONFields.bool(block["eligible"]) ?? false
        let arm = JSONFields.string(block["arm"])
        guard eligible, arm == "reset" else { return .none }
        let available = JSONFields.bool(block["available"]) ?? false
        let expires = JSONFields.date(from: available ? block["weekly_resets_at"] : block["next_available_at"])
            ?? JSONFields.date(from: block["weekly_resets_at"])
        if let expires, expires <= now, !available { return .none }
        return .grants([
            LimitReset(
                id: "juniper_tide",
                remaining: available ? 1 : 0,
                restores: "the 5-hour session",
                expiresAt: expires,
                available: available
            )
        ])
    }

    private static func restores(_ clears: [String]) -> String {
        let names = clears.map(windowName)
        return switch names.count {
        case 0: "your usage limit"
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default:
            names.dropLast().joined(separator: ", ") + ", and " + (names.last ?? "your usage limit")
        }
    }

    private static func windowName(_ id: String) -> String {
        switch id {
        case "five_hour", "anthropic:5h":
            return "the 5-hour session"
        case "seven_day", "anthropic:7d", "weekly_all":
            return "the weekly limit"
        case "seven_day_opus", "anthropic:7d:opus":
            return "the Opus weekly limit"
        case "seven_day_sonnet", "anthropic:7d:sonnet":
            return "the Sonnet weekly limit"
        default:
            return "the \(id.replacingOccurrences(of: "anthropic:", with: "").replacingOccurrences(of: "_", with: " ")) limit"
        }
    }

    private static func wholeNumber(_ value: Any?) -> Int? {
        guard let number = JSONFields.double(value), number >= 0, number.rounded() == number else { return nil }
        return Int(number)
    }

    /// Usable banked resets. Matches Claude Usage Bar: eligible, not paused, inside the grant window.
    static func parseLimitResets(_ raw: Any?, now: Date) -> (left: Int, endAt: Date?) {
        guard let object = JSONFields.dictionary(raw),
              JSONFields.bool(object["eligible"]) == true,
              let grants = object["grants"] as? [Any]
        else { return (0, nil) }
        var total = 0
        var earliest: Date?
        for item in grants {
            guard let grant = item as? [String: Any] else { continue }
            guard let left = wholeNumber(grant["resets_left"]), left > 0 else { continue }
            if JSONFields.bool(grant["paused"]) == true { continue }
            guard let end = JSONFields.date(from: grant["ends_at"]), end > now else { continue }
            if let start = JSONFields.date(from: grant["starts_at"]), start > now { continue }
            total += left
            earliest = min(earliest ?? end, end)
        }
        return (total, earliest)
    }

    static func freeCredits(from data: Data) -> (minor: Int, currency: String?)? {
        guard let json = JSONFields.decodeObject(data) else { return nil }
        let minor: Int
        if let amount = wholeNumber(json["amount"]) {
            minor = amount
        } else {
            var remaining = 0
            for key in ["tranches", "promo_tranches"] {
                guard let items = json[key] as? [Any] else { continue }
                for item in items {
                    guard let tranche = item as? [String: Any] else { continue }
                    remaining += wholeNumber(tranche["remaining_amount_minor_units"]) ?? 0
                }
            }
            minor = remaining
        }
        return (minor, JSONFields.string(json["currency"]))
    }

    static func extraUsage(from data: Data) -> (spent: Int, limit: Int, currency: String, resetsAt: Date?)? {
        guard let json = JSONFields.decodeObject(data) else { return nil }
        return (
            spent: wholeNumber(json["used_credits"]) ?? 0,
            limit: wholeNumber(json["monthly_credit_limit"]) ?? 0,
            currency: JSONFields.string(json["currency"]) ?? "USD",
            resetsAt: JSONFields.date(from: json["disabled_until"])
        )
    }

    static func fableIsActive(in data: Data) -> Bool {
        guard let object = JSONFields.decodeObject(data),
              let limits = object["limits"] as? [Any]
        else { return false }
        for item in limits {
            guard let entry = item as? [String: Any] else { continue }
            let scope = entry["scope"] as? [String: Any]
            let model = scope?["model"] as? [String: Any]
            let name = JSONFields.string(model?["display_name"]) ?? JSONFields.string(entry["display_name"])
            guard name == "Fable" else { continue }
            let percent = JSONFields.double(entry["percent"]) ?? JSONFields.double(entry["utilization"]) ?? 0
            return percent >= 1
        }
        return false
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
        let fetchedAt = now()
        var snapshot = try ClaudeUsageMapping.snapshot(from: usage.body, fetchedAt: fetchedAt)
        snapshot.extras = await accountExtras(usageBody: usage.body, orgID: orgID, cookie: cookie, now: fetchedAt)
        snapshot.resets = await resolveResets(initial: usage.body, orgID: orgID, cookie: cookie, now: fetchedAt)
        return snapshot
    }

    private func accountExtras(usageBody: Data, orgID: String, cookie: String, now: Date) async -> ClaudeAccountExtras {
        async let creditsBody = loadQuietly(ClaudeRequests.prepaidCreditsURL(orgID: orgID), cookie: cookie)
        async let overageBody = loadQuietly(ClaudeRequests.overageURL(orgID: orgID), cookie: cookie)
        async let resetBody = probe(orgID: orgID, cookie: cookie, query: "cedar_ember=1&skip_spend=1")

        var extras = ClaudeAccountExtras(fableActive: ClaudeUsageMapping.fableIsActive(in: usageBody))
        if let data = await creditsBody, let credits = ClaudeUsageMapping.freeCredits(from: data) {
            extras.freeCreditsMinor = credits.minor
            if let currency = credits.currency { extras.currency = currency }
        }
        if let data = await overageBody, let extra = ClaudeUsageMapping.extraUsage(from: data) {
            extras.spentMinor = extra.spent
            extras.limitMinor = extra.limit
            extras.currency = extra.currency
            extras.extraResetsAt = extra.resetsAt
        }
        let resetPayload = await resetBody ?? usageBody
        if let object = JSONFields.decodeObject(resetPayload) {
            let parsed = ClaudeUsageMapping.parseLimitResets(object["cedar_ember"], now: now)
            extras.limitResetsLeft = parsed.left
            extras.limitResetsEndAt = parsed.endAt
        }
        return extras
    }

    private func loadQuietly(_ url: URL?, cookie: String) async -> Data? {
        guard let url else { return nil }
        return await probe(url: url, cookie: cookie)
    }

    private func resolveResets(initial: Data, orgID: String, cookie: String, now: Date) async -> ResetInventory? {
        var read = ClaudeUsageMapping.resetRead(from: initial, now: now)
        if read.cedar == nil, let probed = await probe(orgID: orgID, cookie: cookie, query: "cedar_ember=1&skip_spend=1") {
            let next = ClaudeUsageMapping.resetRead(from: probed, now: now)
            read.cedar = next.cedar ?? read.cedar
            read.juniper = next.juniper ?? read.juniper
        }
        let cedarHasGrant: Bool
        if case .grants = read.cedar { cedarHasGrant = true } else { cedarHasGrant = false }
        if !cedarHasGrant, read.juniper == nil,
           let probed = await probe(orgID: orgID, cookie: cookie, query: "at_wall=1&skip_spend=1") {
            let next = ClaudeUsageMapping.resetRead(from: probed, now: now)
            read.juniper = next.juniper ?? read.juniper
            read.cedar = read.cedar ?? next.cedar
        }
        return ClaudeUsageMapping.inventory(combining: read)
    }

    private func probe(orgID: String, cookie: String, query: String) async -> Data? {
        guard let url = ClaudeRequests.usageURL(orgID: orgID, probe: query) else { return nil }
        return await probe(url: url, cookie: cookie)
    }

    private func probe(url: URL, cookie: String) async -> Data? {
        do {
            let response = try await http.send(ClaudeRequests.make(url: url, cookie: cookie))
            guard (200..<300).contains(response.statusCode) else { return nil }
            return response.body
        } catch {
            return nil
        }
    }
}
