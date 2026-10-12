import XCTest
@testable import AIUsageWidget

final class AppUpdateTests: XCTestCase {
    func testVersionOrderIgnoresPrefixAndPadsMissingParts() {
        XCTAssertTrue(AppUpdate.isNewer("0.2.0", than: "0.1.0"))
        XCTAssertTrue(AppUpdate.isNewer("v0.1.10", than: "0.1.9"))
        XCTAssertTrue(AppUpdate.isNewer("1.0", than: "0.9.9"))
        XCTAssertFalse(AppUpdate.isNewer("0.1.0", than: "v0.1.0"))
        XCTAssertFalse(AppUpdate.isNewer("0.1", than: "0.1.0"))
        XCTAssertEqual(AppUpdate.compare("v1.2.3", "1.2.3"), .orderedSame)
    }

    func testReleasePrefersTheNamedDiskImage() {
        let body = Data(
            """
            {
              "tag_name": "v0.2.0",
              "html_url": "https://github.com/hgrafa/ai-usage-widget/releases/tag/v0.2.0",
              "assets": [
                {
                  "name": "notes.txt",
                  "browser_download_url": "https://example.test/notes.txt"
                },
                {
                  "name": "Other.dmg",
                  "browser_download_url": "https://example.test/other.dmg"
                },
                {
                  "name": "AI-Usage.dmg",
                  "browser_download_url": "https://example.test/AI-Usage.dmg"
                }
              ]
            }
            """.utf8
        )
        let release = AppUpdate.release(from: body)
        XCTAssertEqual(release?.version, "0.2.0")
        XCTAssertEqual(release?.downloadURL.absoluteString, "https://example.test/AI-Usage.dmg")
        XCTAssertEqual(
            release?.pageURL.absoluteString,
            "https://github.com/hgrafa/ai-usage-widget/releases/tag/v0.2.0"
        )
    }

    func testReleaseFallsBackToTheReleasePage() {
        let body = Data(#"{"tag_name":"v0.1.0","html_url":"https://example.test/rel","assets":[]}"#.utf8)
        XCTAssertEqual(AppUpdate.release(from: body)?.downloadURL.absoluteString, "https://example.test/rel")
        XCTAssertNil(AppUpdate.release(from: Data("[]".utf8)))
    }

    func testCheckReportsNewerReleaseAndSilence() async {
        let newer = Data(
            #"{"tag_name":"v0.2.0","html_url":"https://example.test/rel","assets":[{"name":"AI-Usage.dmg","browser_download_url":"https://example.test/AI-Usage.dmg"}]}"#.utf8
        )
        let available = await UpdateChecker.check(
            current: "0.1.0",
            client: StubHTTPClient(statusCode: 200, body: newer)
        )
        XCTAssertEqual(
            available,
            .available(AppRelease(
                version: "0.2.0",
                pageURL: URL(string: "https://example.test/rel")!,
                downloadURL: URL(string: "https://example.test/AI-Usage.dmg")!
            ))
        )

        let same = await UpdateChecker.check(
            current: "0.2.0",
            client: StubHTTPClient(statusCode: 200, body: newer)
        )
        XCTAssertEqual(same, .upToDate(current: "0.2.0"))
        let missing = await UpdateChecker.check(current: "0.1.0", client: StubHTTPClient(statusCode: 404, body: Data()))
        XCTAssertEqual(missing, .noRelease)
        let broken = await UpdateChecker.check(current: "0.1.0", client: StubHTTPClient(statusCode: 200, body: Data("{" .utf8)))
        XCTAssertEqual(broken, .failed)
        let down = await UpdateChecker.check(current: "0.1.0", client: ThrowingHTTPClient())
        XCTAssertEqual(down, .failed)
    }
}

private struct StubHTTPClient: HTTPClient {
    var statusCode: Int
    var body: Data

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(statusCode: statusCode, body: body)
    }
}

private struct ThrowingHTTPClient: HTTPClient {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        throw UsageFetchError.network
    }
}
