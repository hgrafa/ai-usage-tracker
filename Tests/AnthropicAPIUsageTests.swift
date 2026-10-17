import XCTest
@testable import AIUsageWidget

final class AnthropicAPIUsageTests: XCTestCase {
    /// 2026-10-17T19:00:00Z
    private let now = Date(timeIntervalSince1970: 1_792_263_600)

    func testPasteIsAnAdminKeyOrAConsoleCookie() {
        XCTAssertEqual(AnthropicAPISecret(paste: "  sk-ant-admin01-abc  "), .adminKey("sk-ant-admin01-abc"))
        XCTAssertEqual(
            AnthropicAPISecret(paste: "Cookie: anthropic-device-id=d; sessionKey=sk-ant-sid01-s; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
            .consoleCookie("sessionKey=sk-ant-sid01-s; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        )
        XCTAssertEqual(AnthropicAPISecret(paste: "sk-ant-sid01-bare"), .consoleCookie("sessionKey=sk-ant-sid01-bare"))
        XCTAssertEqual(AnthropicAPISecret(paste: "sk-ant-api03-regular"), .regularAPIKey)
    }

    func testCostReportAsksForThisUTCMonthIncludingToday() throws {
        let request = try XCTUnwrap(AnthropicAPIRequests.costReport(adminKey: "sk-ant-admin01-secret", now: now, page: nil))
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.host, "api.anthropic.com")
        XCTAssertEqual(url.path, "/v1/organizations/cost_report")
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["starting_at"], "2026-10-01T00:00:00Z")
        XCTAssertEqual(query["ending_at"], "2026-10-18T00:00:00Z")
        XCTAssertEqual(query["bucket_width"], "1d")
        XCTAssertEqual(query["limit"], "31")
        XCTAssertNil(query["page"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-admin01-secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertFalse(url.absoluteString.contains("secret"))

        let next = try XCTUnwrap(AnthropicAPIRequests.costReport(adminKey: "k", now: now, page: "page_abc="))
        XCTAssertTrue(next.url?.absoluteString.contains("page=page_abc%3D") == true)
    }

    func testCostReportSumsCentsForTheMonthAndToday() throws {
        let spend = try AnthropicAPIUsageMapping.spend(fromCostReports: [Data(Self.costPage1.utf8), Data(Self.costPage2.utf8)], now: now)
        XCTAssertEqual(spend.monthCents, 199.45, accuracy: 0.000_1)
        XCTAssertEqual(spend.todayCents, 76, accuracy: 0.000_1)
        let snapshot = AnthropicAPIUsageMapping.snapshot(spend: spend, fetchedAt: now)
        XCTAssertEqual(snapshot.provider, .anthropic)
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
        XCTAssertEqual(snapshot.note, "$1.99 spent this month · $0.76 today")
    }

    func testCostReportThatIsNotAReportThrows() {
        XCTAssertThrowsError(try AnthropicAPIUsageMapping.spend(fromCostReports: [Data(#"{"error":{"type":"x"}}"#.utf8)], now: now))
    }

    func testConsoleOrganizationPrefersTheCookieThenAnAPIOrg() throws {
        let orgs = Data("""
        [
          {"uuid":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","capabilities":["chat","claude_pro"]},
          {"uuid":"cccccccc-cccc-cccc-cccc-cccccccccccc","capabilities":["api","api_individual"]}
        ]
        """.utf8)
        XCTAssertEqual(try AnthropicAPIUsageMapping.consoleOrganizationID(cookie: "sessionKey=s", organizations: orgs), "cccccccc-cccc-cccc-cccc-cccccccccccc")
        XCTAssertEqual(
            try AnthropicAPIUsageMapping.consoleOrganizationID(cookie: "sessionKey=s; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", organizations: orgs),
            "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        )
        let chatOnly = Data(#"[{"uuid":"dddddddd-dddd-dddd-dddd-dddddddddddd","capabilities":["chat"]}]"#.utf8)
        XCTAssertEqual(try AnthropicAPIUsageMapping.consoleOrganizationID(cookie: "sessionKey=s", organizations: chatOnly), "dddddddd-dddd-dddd-dddd-dddddddddddd")
        XCTAssertThrowsError(try AnthropicAPIUsageMapping.consoleOrganizationID(cookie: "sessionKey=s", organizations: Data("[]".utf8)))
    }

    func testCreditBalanceIsInCents() throws {
        let reload = try AnthropicAPIUsageMapping.creditSnapshot(
            from: Data(#"{"amount": 3780, "currency": "USD", "auto_reload_settings": {"enabled": true}, "expiry_policy_months": 12}"#.utf8),
            fetchedAt: now
        )
        XCTAssertEqual(reload.note, "$37.80 credit left · auto-reload on")
        XCTAssertTrue(reload.meters.isEmpty)
        XCTAssertNil(reload.menuBarFraction)

        let plain = try AnthropicAPIUsageMapping.creditSnapshot(from: Data(#"{"amount": 0, "currency": "USD"}"#.utf8), fetchedAt: now)
        XCTAssertEqual(plain.note, "$0.00 credit left")
        XCTAssertThrowsError(try AnthropicAPIUsageMapping.creditSnapshot(from: Data(#"{"currency": "USD"}"#.utf8), fetchedAt: now))
    }

    func testConsoleRequestsCarryTheCookieInAHeaderOnly() throws {
        let request = AnthropicAPIRequests.console(url: AnthropicAPIRequests.consoleOrganizationsURL, cookie: "sessionKey=sk-ant-sid01-secret")
        XCTAssertEqual(request.url?.host, "platform.claude.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "sessionKey=sk-ant-sid01-secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://platform.claude.com")
        XCTAssertFalse(try XCTUnwrap(request.url?.absoluteString).contains("secret"))
        let credits = try XCTUnwrap(AnthropicAPIRequests.consoleCreditsURL(orgID: "cccccccc-cccc-cccc-cccc-cccccccccccc"))
        XCTAssertEqual(credits.absoluteString, "https://platform.claude.com/api/organizations/cccccccc-cccc-cccc-cccc-cccccccccccc/prepaid/credits")
    }

    func testAdminKeyFetchFollowsPagesAndShowsSpend() async throws {
        let http = SequenceHTTP([(200, Self.costPage1), (200, Self.costPage2)])
        let store = InMemoryCredentialStore()
        try store.save(Credential(provider: .anthropic, kind: .apiKey, secret: "sk-ant-admin01-k"))
        let fixed = now
        let snapshot = try await AnthropicAPIUsageFetcher(store: store, http: http, now: { fixed }).fetch()
        XCTAssertEqual(snapshot.note, "$1.99 spent this month · $0.76 today")
        XCTAssertEqual(http.requests.count, 2)
        XCTAssertTrue(http.requests[1].url?.absoluteString.contains("page=page_2") == true)
    }

    func testConsoleCookieFetchReadsTheCreditBalance() async throws {
        let http = SequenceHTTP([
            (200, #"[{"uuid":"cccccccc-cccc-cccc-cccc-cccccccccccc","capabilities":["api"]}]"#),
            (200, #"{"amount": 1250, "currency": "USD"}"#)
        ])
        let store = InMemoryCredentialStore()
        try store.save(Credential(provider: .anthropic, kind: .sessionCookie, secret: "sessionKey=sk-ant-sid01-s"))
        let fixed = now
        let snapshot = try await AnthropicAPIUsageFetcher(store: store, http: http, now: { fixed }).fetch()
        XCTAssertEqual(snapshot.note, "$12.50 credit left")
        XCTAssertEqual(http.requests.map { $0.url?.path }, ["/api/organizations", "/api/organizations/cccccccc-cccc-cccc-cccc-cccccccccccc/prepaid/credits"])
    }

    func testRejectedOrWrongKeysSayWhatToPaste() async throws {
        let store = InMemoryCredentialStore()
        try store.save(Credential(provider: .anthropic, kind: .apiKey, secret: "sk-ant-admin01-k"))
        let fixed = now
        do {
            _ = try await AnthropicAPIUsageFetcher(store: store, http: SequenceHTTP([(401, "{}")]), now: { fixed }).fetch()
            XCTFail("expected a rejection")
        } catch {
            XCTAssertEqual(error as? UsageFetchError, .unauthorized(.anthropic))
        }

        try store.save(Credential(provider: .anthropic, kind: .apiKey, secret: "sk-ant-api03-regular"))
        do {
            _ = try await AnthropicAPIUsageFetcher(store: store, http: SequenceHTTP([]), now: { fixed }).fetch()
            XCTFail("expected a message")
        } catch {
            XCTAssertEqual(error as? UsageFetchError, .message(AnthropicAPISecret.regularKeyMessage))
        }
    }

    /// Shaped like the documented cost report: amounts are decimal strings in cents.
    private static let costPage1 = """
    {
      "data": [
        {"starting_at": "2026-10-01T00:00:00Z", "ending_at": "2026-10-02T00:00:00Z", "results": [
          {"amount": "123.45", "context_window": null, "cost_type": null, "currency": "USD", "description": null, "inference_geo": null, "model": null, "service_tier": null, "speed": null, "token_type": null, "workspace_id": null}
        ]},
        {"starting_at": "2026-10-02T00:00:00Z", "ending_at": "2026-10-03T00:00:00Z", "results": []}
      ],
      "has_more": true,
      "next_page": "page_2"
    }
    """

    private static let costPage2 = """
    {
      "data": [
        {"starting_at": "2026-10-17T00:00:00Z", "ending_at": "2026-10-18T00:00:00Z", "results": [
          {"amount": "50", "currency": "USD", "workspace_id": null},
          {"amount": "26", "currency": "USD", "workspace_id": null}
        ]}
      ],
      "has_more": false,
      "next_page": null
    }
    """
}

/// Answers requests in order with canned responses, then 500s.
final class SequenceHTTP: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [HTTPResponse]
    private var sent: [URLRequest] = []

    init(_ responses: [(Int, String)]) {
        queue = responses.map { HTTPResponse(statusCode: $0.0, body: Data($0.1.utf8)) }
    }

    var requests: [URLRequest] {
        lock.withLock { sent }
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        lock.withLock {
            sent.append(request)
            return queue.isEmpty ? HTTPResponse(statusCode: 500, body: Data()) : queue.removeFirst()
        }
    }
}
