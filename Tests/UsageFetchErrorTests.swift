import XCTest
@testable import AIUsageWidget

final class UsageFetchErrorTests: XCTestCase {
    private let secret = "supersecretvalue"

    func testUnauthorizedAndTransportErrorsOmitSecretsAndURLs() {
        let body = Data(
            """
            {"cookie":"sessionKey=\(secret)","url":"https://claude.ai/api?token=\(secret)"}
            """.utf8
        )
        let unauthorized = HTTPFailureMapper.map(statusCode: 401, body: body, provider: .claude, htmlMeansUnauthorized: true)
        XCTAssertEqual(unauthorized, .unauthorized(.claude))
        assertNoSecret(unauthorized?.localizedDescription)

        let forbidden = HTTPFailureMapper.map(statusCode: 403, body: body, provider: .cursor, htmlMeansUnauthorized: false)
        XCTAssertEqual(forbidden, .unauthorized(.cursor))
        XCTAssertEqual(
            forbidden?.errorDescription,
            "Cursor rejected the session. Sign in again, or paste a new token."
        )
        assertNoSecret(forbidden?.localizedDescription)
        XCTAssertFalse(forbidden?.localizedDescription.contains("cursor.sh") ?? true)

        let html = Data("<html><title>\(secret)</title>sessionKey=\(secret)</html>".utf8)
        let cloudflare = HTTPFailureMapper.map(statusCode: 200, body: html, provider: .claude, htmlMeansUnauthorized: true)
        XCTAssertEqual(cloudflare, .unauthorized(.claude))
        assertNoSecret(cloudflare?.localizedDescription)
        XCTAssertFalse(cloudflare?.localizedDescription.contains("<html") ?? true)
        XCTAssertFalse(cloudflare?.localizedDescription.contains("sessionKey") ?? true)

        let cursorHTML = HTTPFailureMapper.map(statusCode: 200, body: html, provider: .cursor, htmlMeansUnauthorized: false)
        XCTAssertNil(cursorHTML)

        let limited = HTTPFailureMapper.map(statusCode: 429, body: body, provider: .grok, htmlMeansUnauthorized: false)
        XCTAssertEqual(limited, .rateLimited)
        assertNoSecret(limited?.localizedDescription)

        let server = HTTPFailureMapper.map(statusCode: 500, body: body, provider: .claude, htmlMeansUnauthorized: true)
        XCTAssertEqual(server, .network)
        assertNoSecret(server?.localizedDescription)

        XCTAssertNil(HTTPFailureMapper.map(statusCode: 200, body: Data("{}".utf8), provider: .claude, htmlMeansUnauthorized: true))
    }

    func testTransportDropsURLAndSystemText() {
        let url = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage?token=\(secret)")!
        let error = UsageFetchError.transport(URLError(.timedOut), url: url)
        XCTAssertEqual(error, .network)
        XCTAssertEqual(error.localizedDescription, "The usage request failed.")
        assertNoSecret(error.localizedDescription)
        XCTAssertFalse(error.localizedDescription.contains("cursor.sh"))
        XCTAssertFalse(error.localizedDescription.lowercased().contains("timed"))
    }

    func testFixedMessagesDoNotMentionSecrets() {
        let samples: [UsageFetchError] = [
            .unauthorized(.claude),
            .unauthorized(.codex),
            .unauthorized(.cursor),
            .unauthorized(.grok),
            .rateLimited,
            .network,
            .malformed,
            .notConfigured,
            .message(CodexAppServerClient.missingCLIMessage),
            .message(CodexAppServerClient.notLoggedInMessage),
            .message(GrokUsageMapping.noAllowanceMessage),
            .message(CursorAccessTokenProvider.missingTokenMessage)
        ]
        for error in samples {
            assertNoSecret(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.contains("http"))
            XCTAssertFalse(error.localizedDescription.contains("sessionKey"))
            XCTAssertFalse(error.localizedDescription.contains("Bearer"))
        }
        XCTAssertEqual(CodexAppServerClient.missingCLIMessage, "Install the Codex CLI and run codex login.")
        XCTAssertEqual(CodexAppServerClient.notLoggedInMessage, "Codex is not logged in. Run codex login in Terminal.")
        XCTAssertFalse(CodexAppServerClient.notLoggedInMessage.contains("auth.json"))
    }

    func testCredentialDescriptionOmitsSecret() {
        let credential = Credential(provider: .claude, kind: .sessionCookie, secret: secret)
        XCTAssertFalse(String(describing: credential).contains(secret))
        XCTAssertFalse(String(reflecting: credential).contains(secret))
        XCTAssertEqual(KeychainCredentialStore.service, "dev.hgrafa.ai-usage-widget")
    }

    private func assertNoSecret(_ text: String?, file: StaticString = #filePath, line: UInt = #line) {
        let text = text ?? ""
        XCTAssertFalse(text.contains(secret), file: file, line: line)
        XCTAssertFalse(text.contains("token="), file: file, line: line)
    }
}
