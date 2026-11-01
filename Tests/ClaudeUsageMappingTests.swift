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
        XCTAssertEqual(ClaudeRequests.cookieHeader(from: "sessionToken=abc"), "sessionKey=abc")
        XCTAssertEqual(
            ClaudeRequests.cookieHeader(from: "sessionKeyV3=from-v3; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
            "sessionKey=from-v3; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        )
        let noisy = """
        anthropic-device-id=device; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb; \
        intercom-session-lupk8zyo=junk; sessionKey=sk-ant-sid02-test; sessionKeyLC=1792150996012; \
        sessionKeyV3=sk-ant-sid02-other; cf_clearance=clearance
        """
        XCTAssertEqual(
            ClaudeRequests.cookieHeader(from: noisy),
            "sessionKey=sk-ant-sid02-test; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        )
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
        XCTAssertNil(ClaudeUsageMapping.inventory(combining: ClaudeUsageMapping.resetRead(from: Data(Self.usage.utf8), now: fetchedAt)))
    }

    func testLimitResetsSumUsableGrantsAndSkipTheRest() {
        let later = "2026-10-23T03:00:00Z"
        let sooner = "2026-10-20T03:00:00Z"
        let json = Data("""
        {
          "eligible": true,
          "grants": [
            {"id": "soon", "resets_left": 1, "ends_at": "\(sooner)", "paused": false},
            {"id": "later", "resets_left": 2, "ends_at": "\(later)"},
            {"id": "paused", "resets_left": 4, "ends_at": "\(later)", "paused": true},
            {"id": "future", "resets_left": 3, "starts_at": "2026-12-01T00:00:00Z", "ends_at": "\(later)"},
            {"id": "expired", "resets_left": 5, "ends_at": "2020-01-01T00:00:00Z"}
          ]
        }
        """.utf8)
        let object = try! JSONSerialization.jsonObject(with: json)
        let parsed = ClaudeUsageMapping.parseLimitResets(object, now: fetchedAt)
        XCTAssertEqual(parsed.left, 3)
        XCTAssertEqual(parsed.endAt, UsageFormatting.parseISO8601(sooner))
        let extras = ClaudeAccountExtras(limitResetsLeft: parsed.left, limitResetsEndAt: parsed.endAt)
        XCTAssertTrue(extras.limitResetCaption?.hasPrefix("3 usage-limit resets available until ") == true)
        XCTAssertNil(ClaudeAccountExtras().limitResetCaption)
    }

    func testIneligibleResetsAreZero() {
        let json = Data(#"{"eligible": false, "grants": [{"resets_left": 1, "ends_at": "2026-10-23T03:00:00Z"}]}"#.utf8)
        let object = try! JSONSerialization.jsonObject(with: json)
        XCTAssertEqual(ClaudeUsageMapping.parseLimitResets(object, now: fetchedAt).left, 0)
    }

    func testFreeCreditsPreferAmountThenTranches() throws {
        let amount = try XCTUnwrap(ClaudeUsageMapping.freeCredits(from: Data(#"{"amount": 250, "currency": "USD"}"#.utf8)))
        XCTAssertEqual(amount.minor, 250)
        XCTAssertEqual(amount.currency, "USD")
        XCTAssertEqual(ClaudeAccountExtras(currency: "USD", freeCreditsMinor: 250).money(250), "$2.50")

        let tranches = try XCTUnwrap(ClaudeUsageMapping.freeCredits(from: Data("""
        {"tranches": [{"remaining_amount_minor_units": 100}], "promo_tranches": [{"remaining_amount_minor_units": 50}]}
        """.utf8)))
        XCTAssertEqual(tranches.minor, 150)
    }

    func testExtraUsageCaptionAndReassurance() throws {
        let extra = try XCTUnwrap(ClaudeUsageMapping.extraUsage(from: Data("""
        {"used_credits": 150, "monthly_credit_limit": 2000, "currency": "USD", "disabled_until": "2026-11-01T00:00:00Z"}
        """.utf8)))
        XCTAssertEqual(extra.spent, 150)
        XCTAssertEqual(extra.limit, 2000)
        var extras = ClaudeAccountExtras(
            currency: extra.currency,
            spentMinor: extra.spent,
            limitMinor: extra.limit,
            extraResetsAt: extra.resetsAt
        )
        XCTAssertEqual(extras.extraCaption, "$1.50 of $20.00 · 8%")
        XCTAssertTrue(extras.extraResetCaption?.hasPrefix("Resets ") == true)

        extras.spentMinor = 2500
        XCTAssertEqual(extras.extraCaption, "$25.00 of $20.00 · over limit")
        XCTAssertEqual(extras.extraFraction, 1)

    }

    func testClaudeCodeUsageShowsTheSameRowsAsTheCookie() throws {
        guard case .usage(let limits) = ClaudeCodeProtocol.read(usage: Data(ClaudeCodeTests.planUsage.utf8)) else {
            return XCTFail("fixture should read as plan usage")
        }
        let snapshot = try ClaudeUsageMapping.planSnapshot(from: limits, fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Session (5 hour)", "Weekly (7 day)"])
        XCTAssertEqual(snapshot.meters[0].fraction ?? -1, 0.06, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.meters[1].fraction ?? -1, 0, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.06, accuracy: 0.000_001)
        XCTAssertNil(snapshot.breakdown)
        let extras = try XCTUnwrap(snapshot.extras)
        XCTAssertEqual(extras.spentMinor, 0)
        XCTAssertNil(snapshot.resets, "null reset blocks are not an answer")
    }

    func testPerModelWeeklyLimitsFromTheClaudeCodeShape() throws {
        let fromLimits = try ClaudeUsageMapping.planSnapshot(from: Data(Self.planWithFable(modelScoped: false).utf8), fetchedAt: fetchedAt)
        let limitSegments = try XCTUnwrap(fromLimits.breakdown).segments
        XCTAssertEqual(limitSegments.map(\.title), ["Fable"])
        XCTAssertEqual(limitSegments.map(\.displayValue), ["40%"])

        let both = try ClaudeUsageMapping.planSnapshot(from: Data(Self.planWithFable(modelScoped: true).utf8), fetchedAt: fetchedAt)
        let segments = try XCTUnwrap(both.breakdown).segments
        XCTAssertEqual(segments.map(\.title), ["Fable"], "model_scoped and limits describe the same window once")
        XCTAssertEqual(segments.map(\.amount), [41])
    }

    func testPlanExtraUsageIsInCents() throws {
        let snapshot = try ClaudeUsageMapping.planSnapshot(from: Data(Self.planWithFable(modelScoped: false).utf8), fetchedAt: fetchedAt)
        let extras = try XCTUnwrap(snapshot.extras)
        XCTAssertEqual(extras.spentMinor, 27140)
        XCTAssertEqual(extras.limitMinor, 50000)
        XCTAssertEqual(extras.extraCaption, "$271.40 of $500.00 · 54%")
    }

    /// Shaped like Claude Code's documented extra_usage example and its limits[] rows.
    private static func planWithFable(modelScoped: Bool) -> String {
        """
        {
          "five_hour": {"utilization": 30, "resets_at": "2026-10-12T18:00:00Z"},
          "seven_day": {"utilization": 12, "resets_at": "2026-10-19T00:00:00Z"},
          "extra_usage": {"is_enabled": true, "monthly_limit": 50000, "used_credits": 27140, "utilization": 54, "currency": "USD"},
          "limits": [
            {"kind": "session", "group": "session", "percent": 30, "severity": "normal", "resets_at": "2026-10-12T18:00:00Z", "scope": null, "is_active": true},
            {"kind": "weekly_all", "group": "weekly", "percent": 12, "severity": "normal", "resets_at": "2026-10-19T00:00:00Z", "scope": null, "is_active": false},
            {"kind": "weekly_scoped", "group": "weekly", "percent": 40, "severity": "normal", "resets_at": "2026-10-19T00:00:00Z", "scope": {"model": {"display_name": "Fable"}}, "is_active": false}
          ]\(modelScoped ? #", "model_scoped": [{"display_name": "Fable", "utilization": 41, "resets_at": "2026-10-19T00:00:00Z"}]"# : "")
        }
        """
    }

    func testNullResetBlockIsNotAnAnswer() {
        let json = Data(#"{"cedar_ember": null, "juniper_tide": null}"#.utf8)
        XCTAssertNil(ClaudeUsageMapping.inventory(combining: ClaudeUsageMapping.resetRead(from: json, now: fetchedAt)))
    }

    func testEvaluatedEmptyResetIsNone() {
        let json = Data(#"{"cedar_ember": {"eligible": false, "grants": []}, "juniper_tide": {"eligible": false, "arm": "control"}}"#.utf8)
        XCTAssertEqual(
            ClaudeUsageMapping.inventory(combining: ClaudeUsageMapping.resetRead(from: json, now: fetchedAt)),
            ResetInventory.none
        )
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
