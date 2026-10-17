import XCTest
@testable import AIUsageWidget

final class ClaudeCodeTests: XCTestCase {
    private let home = "/Users/me"

    func testFindsTheNativeInstallWhenTheAppPathCannotSeeIt() {
        let native = "\(home)/.local/bin/claude"
        let resolved = ClaudeExecutable.resolve(
            pathEnvironment: "/usr/bin:/bin:/usr/sbin:/sbin",
            homeDirectory: home,
            isExecutable: { $0 == native || $0 == "/opt/homebrew/bin/claude" }
        )
        XCTAssertEqual(resolved?.path, native)
    }

    func testFindsTheOlderLocalInstall() {
        let local = "\(home)/.claude/local/claude"
        let resolved = ClaudeExecutable.resolve(
            pathEnvironment: "/usr/bin",
            homeDirectory: home,
            isExecutable: { $0 == local || $0 == "/usr/local/bin/claude" }
        )
        XCTAssertEqual(resolved?.path, local)
    }

    func testPathWinsThenHomebrewThenUsrLocal() {
        let onPath = ClaudeExecutable.resolve(
            pathEnvironment: "/custom/bin:/usr/bin",
            homeDirectory: home,
            isExecutable: { $0 == "/custom/bin/claude" || $0 == "\(home)/.local/bin/claude" }
        )
        XCTAssertEqual(onPath?.path, "/custom/bin/claude")

        let homebrew = ClaudeExecutable.resolve(
            pathEnvironment: "/usr/bin",
            homeDirectory: home,
            isExecutable: { $0 == "/opt/homebrew/bin/claude" || $0 == "/usr/local/bin/claude" }
        )
        XCTAssertEqual(homebrew?.path, "/opt/homebrew/bin/claude")

        let usrLocal = ClaudeExecutable.resolve(pathEnvironment: nil, homeDirectory: nil, isExecutable: { $0 == "/usr/local/bin/claude" })
        XCTAssertEqual(usrLocal?.path, "/usr/local/bin/claude")

        XCTAssertNil(ClaudeExecutable.resolve(pathEnvironment: "/usr/bin", homeDirectory: home, isExecutable: { _ in false }))
    }

    func testCodexLookupStillPrefersItsOwnBinary() {
        let resolved = CodexExecutable.resolve(
            pathEnvironment: "/usr/bin",
            homeDirectory: home,
            isExecutable: { $0 == "\(home)/.local/bin/codex" || $0 == "\(home)/.local/bin/claude" }
        )
        XCTAssertEqual(resolved?.path, "\(home)/.local/bin/codex")
    }

    func testRequestsAreOneControlLineEach() throws {
        let initialize = String(decoding: ClaudeCodeProtocol.initializeLine, as: UTF8.self)
        let usage = String(decoding: ClaudeCodeProtocol.usageLine, as: UTF8.self)
        XCTAssertTrue(initialize.hasSuffix("\n"))
        XCTAssertEqual(initialize.filter { $0 == "\n" }.count, 1)
        XCTAssertEqual(usage.filter { $0 == "\n" }.count, 1)

        let initObject = try XCTUnwrap(JSONFields.decodeObject(Data(initialize.utf8)))
        XCTAssertEqual(initObject["type"] as? String, "control_request")
        XCTAssertEqual(initObject["request_id"] as? String, ClaudeCodeProtocol.initializeID)
        XCTAssertEqual((initObject["request"] as? [String: Any])?["subtype"] as? String, "initialize")

        let usageObject = try XCTUnwrap(JSONFields.decodeObject(Data(usage.utf8)))
        XCTAssertEqual(usageObject["request_id"] as? String, ClaudeCodeProtocol.usageID)
        let request = try XCTUnwrap(usageObject["request"] as? [String: Any])
        XCTAssertEqual(request["subtype"] as? String, "get_usage")
        XCTAssertEqual(request["skip_behaviors"] as? Bool, true)
    }

    func testArgumentsTurnOffHooksMCPAndSessionFiles() {
        let arguments = ClaudeCodeProtocol.arguments
        XCTAssertTrue(arguments.contains("--strict-mcp-config"))
        XCTAssertTrue(arguments.contains("--no-session-persistence"))
        let sources = arguments.firstIndex(of: "--setting-sources").map { arguments.index(after: $0) }
        XCTAssertEqual(sources.map { arguments[$0] }, "")
        XCTAssertEqual(arguments.firstIndex(of: "--input-format").map { arguments[$0 + 1] }, "stream-json")
        XCTAssertEqual(arguments.firstIndex(of: "--output-format").map { arguments[$0 + 1] }, "stream-json")
        XCTAssertTrue(arguments.contains("-p"))
    }

    func testReplyIsFoundAmongHookAndSystemLines() throws {
        let buffer = Data("""
        {"type":"system","subtype":"hook_started","hook_id":"h1"}
        {"type":"control_response","response":{"subtype":"success","request_id":"someone-else","response":{"x":1}}}
        {"type":"control_response","response":{"subtype":"success","request_id":"\(ClaudeCodeProtocol.initializeID)","response":{"account":{"subscriptionType":"Claude Pro"}}}}
        {"type":"control_response","response":{"subtype":"success","request_id":"\(ClaudeCodeProtocol.usageID)","resp
        """.utf8)
        guard case .success(let body) = try XCTUnwrap(ClaudeCodeProtocol.reply(to: ClaudeCodeProtocol.initializeID, in: buffer)) else {
            return XCTFail("expected a success reply")
        }
        XCTAssertNotNil(JSONFields.dictionary(JSONFields.decodeObject(body)?["account"]))
        XCTAssertNil(ClaudeCodeProtocol.reply(to: ClaudeCodeProtocol.usageID, in: buffer), "a half-written line is not a reply")
    }

    func testErrorReplyIsAFailure() {
        let buffer = Data("""
        {"type":"control_response","response":{"subtype":"error","request_id":"\(ClaudeCodeProtocol.usageID)","error":"Unsupported control request subtype: get_usage"}}

        """.utf8)
        XCTAssertEqual(ClaudeCodeProtocol.reply(to: ClaudeCodeProtocol.usageID, in: buffer), .failure)
    }

    func testPlanUsageKeepsTheRateLimitsObject() throws {
        let read = ClaudeCodeProtocol.read(usage: Data(Self.planUsage.utf8))
        guard case .usage(let limits) = read else { return XCTFail("expected plan usage, got \(read)") }
        let object = try XCTUnwrap(JSONFields.decodeObject(limits))
        XCTAssertEqual(JSONFields.double(JSONFields.dictionary(object["five_hour"])?["utilization"]), 6)
        XCTAssertNotNil(object["extra_usage"])
        XCTAssertNil(object["session"], "session cost is not part of the rate limits")
    }

    func testAvailableButEmptyLimitsMeansClaudeDidNotAnswer() {
        let json = #"{"session":{"total_cost_usd":0},"subscription_type":"pro","rate_limits_available":true,"rate_limits":null,"behaviors":null}"#
        XCTAssertEqual(ClaudeCodeProtocol.read(usage: Data(json.utf8)), .unanswered)
        let windowless = #"{"subscription_type":"pro","rate_limits_available":true,"rate_limits":{"five_hour":null,"seven_day":null}}"#
        XCTAssertEqual(ClaudeCodeProtocol.read(usage: Data(windowless.utf8)), .unanswered)
    }

    func testUnavailableLimitsMeansNoPlan() {
        let json = #"{"session":{"total_cost_usd":0},"subscription_type":null,"rate_limits_available":false,"rate_limits":null,"behaviors":null}"#
        XCTAssertEqual(ClaudeCodeProtocol.read(usage: Data(json.utf8)), .noPlanLimits)
    }

    func testUnreadableUsageIsUnavailable() {
        XCTAssertEqual(ClaudeCodeProtocol.read(usage: Data("[]".utf8)), .unavailable)
        XCTAssertEqual(ClaudeCodeProtocol.read(usage: Data(#"{"session":{}}"#.utf8)), .unavailable)
    }

    func testAuthStatusSaysWhetherClaudeCodeIsSignedIn() {
        XCTAssertEqual(ClaudeCodeProtocol.isLoggedIn(authStatus: Data(#"{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty"}"#.utf8)), true)
        XCTAssertEqual(ClaudeCodeProtocol.isLoggedIn(authStatus: Data(#"{"loggedIn":false}"#.utf8)), false)
        XCTAssertNil(ClaudeCodeProtocol.isLoggedIn(authStatus: Data("Not logged in".utf8)))
    }

    func testSavedLoginIsFreshUntilItExpires() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let later = Self.credentials(expiresAt: now.addingTimeInterval(3600))
        XCTAssertEqual(ClaudeCodeCredentials.read(later, now: now), .fresh("sk-ant-oat01-test-access"))

        let past = Self.credentials(expiresAt: now.addingTimeInterval(-60))
        XCTAssertEqual(ClaudeCodeCredentials.read(past, now: now), .expired)

        let aboutToLapse = Self.credentials(expiresAt: now.addingTimeInterval(20))
        XCTAssertEqual(ClaudeCodeCredentials.read(aboutToLapse, now: now), .expired, "a token that lapses mid-request reads as expired")
    }

    func testSavedLoginWithoutProfileScopeCannotReadUsage() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let inferenceOnly = Self.credentials(expiresAt: now.addingTimeInterval(3600), scopes: ["user:inference"])
        XCTAssertEqual(ClaudeCodeCredentials.read(inferenceOnly, now: now), .missing)
    }

    func testMissingOrBrokenSavedLogin() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        XCTAssertEqual(ClaudeCodeCredentials.read(Data(), now: now), .missing)
        XCTAssertEqual(ClaudeCodeCredentials.read(Data(#"{"mcpOAuth":{}}"#.utf8), now: now), .missing)
        XCTAssertEqual(ClaudeCodeCredentials.read(Data(#"{"claudeAiOauth":{"accessToken":"  "}}"#.utf8), now: now), .missing)
    }

    func testKeychainCopyWinsOverTheCredentialsFile() throws {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let folder = home.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var fileCopy = String(decoding: Self.credentials(expiresAt: now.addingTimeInterval(3600)), as: UTF8.self)
        fileCopy = fileCopy.replacingOccurrences(of: "test-access", with: "from-file")
        try Data(fileCopy.utf8).write(to: folder.appendingPathComponent(".credentials.json"))

        let keychain = Self.credentials(expiresAt: now.addingTimeInterval(3600))
        let both = ClaudeCodeCredentials(homeDirectory: home.path, keychain: { keychain })
        XCTAssertEqual(both.token(now: now), .fresh("sk-ant-oat01-test-access"))

        let fileOnly = ClaudeCodeCredentials(homeDirectory: home.path, keychain: { nil })
        XCTAssertEqual(fileOnly.token(now: now), .fresh("sk-ant-oat01-from-file"))

        let neither = ClaudeCodeCredentials(homeDirectory: home.appendingPathComponent("nobody").path, keychain: { nil })
        XCTAssertEqual(neither.token(now: now), .missing)
    }

    func testOAuthUsageRequestCarriesTheTokenInAHeaderOnly() throws {
        let request = ClaudeOAuthUsage.request(token: "sk-ant-oat01-secret")
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-ant-oat01-secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        XCTAssertFalse(try XCTUnwrap(request.url?.absoluteString).contains("secret"))
    }

    func testClaudeCodeUsageWinsWithoutTouchingTheSavedLogin() async {
        let body = Data(#"{"five_hour":{"utilization":6}}"#.utf8)
        var asked = false
        let route = await ClaudeSources.route(code: .usage(body), hasCookie: true, token: { asked = true; return .fresh("t") })
        XCTAssertEqual(route, .claudeCode(body))
        XCTAssertFalse(asked)
    }

    func testMissingCLIFallsBackToTheSavedLoginThenTheCookie() async {
        let token = await ClaudeSources.route(code: .unavailable, hasCookie: true, token: { .fresh("t") })
        let cookie = await ClaudeSources.route(code: .unavailable, hasCookie: true, token: { .missing })
        let nothing = await ClaudeSources.route(code: .unavailable, hasCookie: false, token: { .missing })
        XCTAssertEqual(token, .token("t"))
        XCTAssertEqual(cookie, .cookie)
        XCTAssertEqual(nothing, .fail(.notConfigured))
    }

    func testExpiredSavedLoginUsesTheCookieOrSaysToOpenClaudeCode() async {
        let cookie = await ClaudeSources.route(code: .unavailable, hasCookie: true, token: { .expired })
        let nothing = await ClaudeSources.route(code: .unavailable, hasCookie: false, token: { .expired })
        XCTAssertEqual(cookie, .cookie)
        XCTAssertEqual(nothing, .fail(.message(ClaudeSources.expiredMessage)))
    }

    func testSignedOutClaudeCodeGoesStraightToTheCookie() async {
        var asked = false
        let cookie = await ClaudeSources.route(code: .signedOut, hasCookie: true, token: { asked = true; return .fresh("t") })
        let nothing = await ClaudeSources.route(code: .signedOut, hasCookie: false, token: { asked = true; return .fresh("t") })
        XCTAssertEqual(cookie, .cookie)
        XCTAssertEqual(nothing, .fail(.notConfigured))
        XCTAssertFalse(asked)
    }

    func testConsoleLoginPointsAtTheAnthropicAPIRowUnlessACookieIsSaved() async {
        let cookie = await ClaudeSources.route(code: .noPlanLimits, hasCookie: true, token: { .fresh("t") })
        let nothing = await ClaudeSources.route(code: .noPlanLimits, hasCookie: false, token: { .fresh("t") })
        XCTAssertEqual(cookie, .cookie)
        XCTAssertEqual(nothing, .note(ClaudeSources.consoleMessage))
    }

    func testUnansweredCLIRetriesWithTheSavedLoginButNeverSwitchesToTheCookie() async {
        let token = await ClaudeSources.route(code: .unanswered, hasCookie: true, token: { .fresh("t") })
        let missing = await ClaudeSources.route(code: .unanswered, hasCookie: true, token: { .missing })
        let expired = await ClaudeSources.route(code: .unanswered, hasCookie: true, token: { .expired })
        XCTAssertEqual(token, .token("t"))
        XCTAssertEqual(missing, .fail(.network))
        XCTAssertEqual(expired, .fail(.network))
    }

    func testRejectedSavedLoginFallsBackToTheCookie() {
        XCTAssertEqual(ClaudeSources.afterTokenRejected(hasCookie: true), .cookie)
        XCTAssertEqual(ClaudeSources.afterTokenRejected(hasCookie: false), .fail(.message(ClaudeSources.expiredMessage)))
    }

    /// Mirrors the "Claude Code-credentials" Keychain item Claude Code 2.1 writes.
    static func credentials(expiresAt: Date, scopes: [String] = ["user:file_upload", "user:inference", "user:mcp_servers", "user:plugins", "user:profile", "user:sessions:claude_code"]) -> Data {
        let object: [String: Any] = [
            "claudeAiOauth": [
                "accessToken": "sk-ant-oat01-test-access",
                "refreshToken": "sk-ant-ort01-test-refresh",
                "expiresAt": Int(expiresAt.timeIntervalSince1970 * 1000),
                "refreshTokenExpiresAt": Int(expiresAt.timeIntervalSince1970 * 1000) + 86_400_000,
                "scopes": scopes,
                "subscriptionType": "pro",
                "rateLimitTier": "default_claude_ai"
            ],
            "mcpOAuth": [:]
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    /// Captured from `get_usage` on Claude Code 2.1.302 for a Pro account, nulls trimmed.
    static let planUsage = """
    {
      "session": {"total_cost_usd": 0, "total_api_duration_ms": 0, "total_duration_ms": 787, "total_lines_added": 0, "total_lines_removed": 0, "model_usage": {}},
      "subscription_type": "pro",
      "rate_limits_available": true,
      "rate_limits": {
        "five_hour": {"utilization": 6, "resets_at": "2026-10-18T00:29:59.860064+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null, "locked_reason": null},
        "seven_day": {"utilization": 0, "resets_at": "2026-10-24T16:59:59.860089+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null, "locked_reason": null},
        "seven_day_opus": null,
        "seven_day_sonnet": null,
        "juniper_tide": null,
        "cedar_ember": null,
        "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null, "currency": null, "decimal_places": null, "disabled_reason": null, "user_disabled": true, "spend_limit_reached": false, "credits_ever_enabled": true, "daily": null, "weekly": null},
        "limits": [
          {"kind": "session", "group": "session", "percent": 6, "severity": "normal", "resets_at": "2026-10-18T00:29:59.860064+00:00", "scope": null, "is_active": true},
          {"kind": "weekly_all", "group": "weekly", "percent": 0, "severity": "normal", "resets_at": "2026-10-24T16:59:59.860089+00:00", "scope": null, "is_active": false}
        ],
        "spend": {"used": {"amount_minor": 0, "currency": "USD", "exponent": 2}, "limit": null, "percent": 0, "severity": "normal", "enabled": false, "disabled_reason": null, "cap": null, "balance": null, "auto_reload": null, "can_purchase_credits": false, "can_toggle": false},
        "member_dashboard_available": false,
        "seven_day_breakdown": null,
        "weekly_scoped_shares": null,
        "model_scoped": []
      },
      "behaviors": null
    }
    """
}
