import XCTest
@testable import AIUsageWidget

/// Runs the real process code against small shell scripts that speak Claude Code's control protocol.
final class ClaudeCodeProcessTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("claude-fake-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testReadsPlanUsageAndStopsTheCLI() async throws {
        let usage = Self.reply(id: ClaudeCodeProtocol.usageID, body: #"{"subscription_type":"pro","rate_limits_available":true,"rate_limits":{"five_hour":{"utilization":6,"resets_at":"2026-10-18T00:29:59Z"}}}"#)
        let script = try fake("""
        read request
        echo '{"type":"system","subtype":"hook_started"}'
        echo '\(Self.reply(id: ClaudeCodeProtocol.initializeID, body: #"{"account":{}}"#))'
        read request
        case "$request" in *get_usage*) echo '\(usage)' ;; *) exit 3 ;; esac
        sleep 30
        """)
        let started = Date()
        let read = await ClaudeCodeClient(locate: { script }, timeout: 10).read()
        guard case .usage(let limits) = read else { return XCTFail("expected usage, got \(read)") }
        XCTAssertEqual(JSONFields.double(JSONFields.dictionary(JSONFields.decodeObject(limits)?["five_hour"])?["utilization"]), 6)
        XCTAssertLessThan(Date().timeIntervalSince(started), 8, "the CLI is stopped once it answers")
    }

    func testPassesTheQuietArguments() async throws {
        let script = try fake("""
        for argument in "$@"; do
          if [ "$argument" = "--strict-mcp-config" ]; then strict=yes; fi
        done
        [ "$strict" = yes ] || exit 4
        read request
        echo '\(Self.reply(id: ClaudeCodeProtocol.initializeID, body: "{}"))'
        read request
        echo '\(Self.reply(id: ClaudeCodeProtocol.usageID, body: #"{"rate_limits_available":true,"rate_limits":null}"#))'
        """)
        let read = await ClaudeCodeClient(locate: { script }, timeout: 10).read()
        XCTAssertEqual(read, .unanswered)
    }

    func testNoPlanLimitsAsksAuthStatusWhetherAnyoneIsSignedIn() async throws {
        let signedOut = try fake(noPlanScript(loggedIn: false), name: "signed-out")
        let signedOutRead = await ClaudeCodeClient(locate: { signedOut }, timeout: 10).read()
        XCTAssertEqual(signedOutRead, .signedOut)

        let console = try fake(noPlanScript(loggedIn: true), name: "console")
        let consoleRead = await ClaudeCodeClient(locate: { console }, timeout: 10).read()
        XCTAssertEqual(consoleRead, .noPlanLimits)
    }

    func testMissingCrashedOrOldCLIIsUnavailable() async throws {
        let missing = await ClaudeCodeClient(locate: { nil }, timeout: 10).read()
        XCTAssertEqual(missing, .unavailable)

        let crash = try fake("exit 1", name: "crash")
        let crashRead = await ClaudeCodeClient(locate: { crash }, timeout: 10).read()
        XCTAssertEqual(crashRead, .unavailable)

        let old = try fake("""
        read request
        echo '\(Self.reply(id: ClaudeCodeProtocol.initializeID, body: "{}"))'
        read request
        echo '{"type":"control_response","response":{"subtype":"error","request_id":"\(ClaudeCodeProtocol.usageID)","error":"Unsupported control request subtype: get_usage"}}'
        sleep 30
        """, name: "old")
        let oldRead = await ClaudeCodeClient(locate: { old }, timeout: 10).read()
        XCTAssertEqual(oldRead, .unavailable)
    }

    func testSilentCLITimesOut() async throws {
        let silent = try fake("sleep 30", name: "silent")
        let started = Date()
        let read = await ClaudeCodeClient(locate: { silent }, timeout: 1).read()
        XCTAssertEqual(read, .unavailable)
        XCTAssertLessThan(Date().timeIntervalSince(started), 6)
    }

    private func noPlanScript(loggedIn: Bool) -> String {
        """
        if [ "$1" = "auth" ] && [ "$2" = "status" ]; then echo '{"loggedIn":\(loggedIn)}'; exit 0; fi
        read request
        echo '\(Self.reply(id: ClaudeCodeProtocol.initializeID, body: "{}"))'
        read request
        echo '\(Self.reply(id: ClaudeCodeProtocol.usageID, body: #"{"subscription_type":null,"rate_limits_available":false,"rate_limits":null}"#))'
        sleep 30
        """
    }

    private func fake(_ body: String, name: String = "claude") throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private static func reply(id: String, body: String) -> String {
        #"{"type":"control_response","response":{"subtype":"success","request_id":"\#(id)","response":\#(body)}}"#
    }
}

final class ClaudeUsageFetcherTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    func testClaudeCodeAnswerIsUsedWithoutAnyRequest() async throws {
        let http = RecordingHTTP(status: 500, body: "{}")
        let fetcher = makeFetcher(code: .usage(Data(#"{"five_hour":{"utilization":6}}"#.utf8)), token: .fresh("t"), http: http)
        let snapshot = try await fetcher.fetch()
        XCTAssertEqual(snapshot.meters.first?.fraction ?? -1, 0.06, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.source, ClaudeUsageMapping.claudeCodeSource)
        XCTAssertTrue(http.requests.isEmpty)
    }

    func testSavedLoginAsksTheUsageEndpointWithTheToken() async throws {
        let http = RecordingHTTP(status: 200, body: #"{"five_hour":{"utilization":21},"seven_day":{"utilization":2}}"#)
        let fetcher = makeFetcher(code: .unavailable, token: .fresh("sk-ant-oat01-x"), http: http)
        let snapshot = try await fetcher.fetch()
        XCTAssertEqual(snapshot.meters.map(\.id), ["session", "weekly"])
        XCTAssertEqual(snapshot.source, ClaudeUsageMapping.claudeCodeSource)
        XCTAssertEqual(http.requests.map { $0.url?.host }, ["api.anthropic.com"])
        XCTAssertEqual(http.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-ant-oat01-x")
    }

    func testRejectedSavedLoginWithoutACookieSaysToOpenClaudeCode() async {
        let fetcher = makeFetcher(code: .unavailable, token: .fresh("old"), http: RecordingHTTP(status: 401, body: "{}"))
        await assertThrows(fetcher, .message(ClaudeSources.expiredMessage))
    }

    func testRateLimitedSavedLoginIsReportedAsRateLimited() async {
        let fetcher = makeFetcher(code: .unanswered, token: .fresh("t"), http: RecordingHTTP(status: 429, body: "{}"))
        await assertThrows(fetcher, .rateLimited)
    }

    func testConsoleLoginShowsANoteInsteadOfAnError() async throws {
        let snapshot = try await makeFetcher(code: .noPlanLimits, token: .missing, http: RecordingHTTP(status: 500, body: "")).fetch()
        XCTAssertEqual(snapshot.note, ClaudeSources.consoleMessage)
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
    }

    func testNothingFoundIsNotConfigured() async {
        let http = RecordingHTTP(status: 200, body: "{}")
        let fetcher = makeFetcher(code: .unavailable, token: .missing, http: http)
        await assertThrows(fetcher, .notConfigured)
        XCTAssertTrue(http.requests.isEmpty)
    }

    func testSignedOutClaudeCodeWithACookieUsesClaudeAI() async throws {
        let http = RecordingHTTP(status: 200, body: #"{"five_hour":{"utilization":47},"seven_day":{"utilization":12}}"#)
        let store = InMemoryCredentialStore()
        try store.save(Credential(provider: .claude, kind: .sessionCookie, secret: "sessionKey=s; lastActiveOrg=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        let fetcher = makeFetcher(code: .signedOut, token: .fresh("unused"), http: http, store: store)
        let snapshot = try await fetcher.fetch()
        XCTAssertNil(snapshot.source)
        XCTAssertEqual(http.requests.first?.url?.host, "claude.ai")
        XCTAssertFalse(http.requests.contains { $0.url?.host == "api.anthropic.com" })
    }

    private func makeFetcher(
        code: ClaudeCodeRead,
        token: ClaudeTokenRead,
        http: RecordingHTTP,
        store: InMemoryCredentialStore = InMemoryCredentialStore()
    ) -> ClaudeUsageFetcher {
        let fixed = now
        return ClaudeUsageFetcher(
            store: store,
            http: http,
            claudeCode: { code },
            savedLogin: { _ in token },
            now: { fixed }
        )
    }

    private func assertThrows(_ fetcher: ClaudeUsageFetcher, _ expected: UsageFetchError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await fetcher.fetch()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? UsageFetchError, expected, file: file, line: line)
        }
    }
}

/// Answers every request with one canned response and remembers what was sent.
final class RecordingHTTP: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [URLRequest] = []
    private let response: HTTPResponse

    init(status: Int, body: String) {
        response = HTTPResponse(statusCode: status, body: Data(body.utf8))
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return sent
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        lock.withLock { sent.append(request) }
        return response
    }
}

final class InMemoryCredentialStore: CredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [ProviderID: Credential] = [:]

    func load(provider: ProviderID) throws -> Credential? {
        lock.lock()
        defer { lock.unlock() }
        return items[provider]
    }

    func save(_ credential: Credential) throws {
        lock.lock()
        items[credential.provider] = credential
        lock.unlock()
    }

    func delete(provider: ProviderID) throws {
        lock.lock()
        items[provider] = nil
        lock.unlock()
    }

    func contains(provider: ProviderID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return items[provider] != nil
    }
}
