import XCTest
@testable import AIUsageWidget

final class ClaudeUsageMappingTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testCookieHeaderFormatsBareValueAndFullHeader() {
        XCTAssertEqual(ClaudeRequests.cookieHeader(from: "abc"), "sessionKey=abc")
        XCTAssertEqual(
            ClaudeRequests.cookieHeader(from: "  sessionKey=abc; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb  "),
            "sessionKey=abc; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        )
        XCTAssertEqual(ClaudeRequests.cookieHeader(from: "Cookie: sessionKey=abc"), "sessionKey=abc")
    }

    func testUsageRequestKeepsCookieOutOfTheURL() throws {
        let cookie = "sessionKey=test-session-value; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        let url = try XCTUnwrap(ClaudeRequests.usageURL(orgID: "org-1"))
        let request = ClaudeRequests.make(url: url, cookie: cookie)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), cookie)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "*/*")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://claude.ai")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://claude.ai")
        XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("Chrome/120") == true)
        XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("Macintosh") == true)
        XCTAssertEqual(request.url?.path, "/api/organizations/org-1/usage")
        XCTAssertNil(request.url?.query)
        let absolute = try XCTUnwrap(request.url?.absoluteString)
        XCTAssertFalse(absolute.contains("sessionKey"))
        XCTAssertFalse(absolute.contains("test-session-value"))
    }

    func testLastActiveOrgWinsOverTheOrganizationList() throws {
        let cookie = "sessionKey=test-session-value; lastActiveOrg=cccccccc-cccc-cccc-cccc-cccccccccccc"
        XCTAssertEqual(
            ClaudeUsageMapping.organizationID(inCookie: cookie),
            "cccccccc-cccc-cccc-cccc-cccccccccccc"
        )
        let picked = try ClaudeUsageMapping.chatOrganizationID(from: Data(Self.orgs.utf8))
        XCTAssertEqual(picked, "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
    }

    func testOrganizationListPicksChatInsteadOfTheFirstOrg() throws {
        XCTAssertNil(ClaudeUsageMapping.organizationID(inCookie: "sessionKey=test-session-value"))
        XCTAssertEqual(
            try ClaudeUsageMapping.chatOrganizationID(from: Data(Self.orgs.utf8)),
            "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        )
    }

    func testMissingChatOrganizationDoesNotUseTheFirstOrg() {
        let json = Data(#"[{"uuid":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","capabilities":["api"]}]"#.utf8)
        XCTAssertThrowsError(try ClaudeUsageMapping.chatOrganizationID(from: json)) { error in
            XCTAssertEqual(error as? UsageFetchError, .message(ClaudeUsageMapping.noChatOrganizationMessage))
        }
    }

    func testUsageMapsSessionWeeklyAndWeeklyScopedModels() throws {
        let snapshot = try ClaudeUsageMapping.snapshot(from: Data(Self.usage.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Session (5 hour)", "Weekly (7 day)"])
        XCTAssertEqual(snapshot.meters[0].fraction ?? -1, 0.47, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.meters[1].fraction ?? -1, 0.12, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.meters[0].caption.hasPrefix("47% used"), true)
        XCTAssertTrue(snapshot.meters[0].caption.contains("resets"))
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.47, accuracy: 0.000_001)
        let segments = try XCTUnwrap(snapshot.breakdown).segments
        XCTAssertEqual(segments.map(\.title), ["Opus", "Sonnet"])
        XCTAssertEqual(segments.map(\.displayValue), ["12%", "3%"])
        XCTAssertEqual(segments.map(\.color), [.purple, .green])
        XCTAssertEqual(segments.map(\.amount), [12.0, 3.0])
        XCTAssertFalse(segments.contains { $0.title.contains("Session") || $0.title.contains("Weekly") || $0.title == "Ignored" })
        XCTAssertFalse(snapshot.meters.contains { $0.title == "Opus" || $0.caption.contains("$") })
    }

    private static let orgs = """
    [
      {"uuid":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","capabilities":["api"]},
      {"uuid":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","capabilities":["chat","claude_pro"]}
    ]
    """

    private static let usage = """
    {
      "five_hour": {"utilization": 47, "resets_at": "2026-10-12T18:00:00Z"},
      "seven_day": {"utilization": 12, "resets_at": "2026-10-19T00:00:00Z"},
      "extra_usage": {"amount": 0, "currency": "USD"},
      "overage": {"amount": 15},
      "limits": [
        {"type": "weekly_scoped", "display_name": "Opus", "utilization": 12, "model": "claude-opus"},
        {"type": "weekly_scoped", "display_name": "Sonnet", "utilization": 3},
        {"type": "weekly_scoped", "utilization": 50},
        {"type": "weekly_scoped", "display_name": "Haiku"},
        {"type": "other", "display_name": "Ignored", "utilization": 99}
      ]
    }
    """
}
