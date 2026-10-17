import XCTest
@testable import AIUsageWidget

final class RefreshBackoffTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_789_000_000)

    func testRateLimitedProviderWaitsTenMinutes() {
        var backoff = RefreshBackoff()
        backoff.record(.claude, result: .failure(.rateLimited), at: start)
        XCTAssertTrue(backoff.isWaiting(.claude, now: start.addingTimeInterval(2 * 60)))
        XCTAssertTrue(backoff.isWaiting(.claude, now: start.addingTimeInterval(9 * 60 + 59)))
        XCTAssertFalse(backoff.isWaiting(.claude, now: start.addingTimeInterval(10 * 60)))
    }

    func testOtherProvidersAndOtherErrorsDoNotWait() {
        var backoff = RefreshBackoff()
        backoff.record(.claude, result: .failure(.rateLimited), at: start)
        backoff.record(.cursor, result: .failure(.network), at: start)
        XCTAssertFalse(backoff.isWaiting(.codex, now: start.addingTimeInterval(60)))
        XCTAssertFalse(backoff.isWaiting(.cursor, now: start.addingTimeInterval(60)))
    }

    func testAnAnswerClearsTheWait() {
        var backoff = RefreshBackoff()
        backoff.record(.claude, result: .failure(.rateLimited), at: start)
        let snapshot = UsageSnapshot(provider: .claude, fetchedAt: start, meters: [])
        backoff.record(.claude, result: .success(snapshot), at: start.addingTimeInterval(11 * 60))
        backoff.record(.claude, result: .failure(.network), at: start.addingTimeInterval(12 * 60))
        XCTAssertFalse(backoff.isWaiting(.claude, now: start.addingTimeInterval(12 * 60 + 1)))
    }

    func testAutoRefreshIsMoreOftenThanTheBackoff() {
        XCTAssertLessThan(AppModel.autoRefreshInterval, RefreshBackoff.wait)
    }

    func testNothingToReadShowsTheSetupPromptInsteadOfAnError() {
        XCTAssertEqual(AppModel.phase(after: .failure(.notConfigured), stale: nil), .unconfigured)
        XCTAssertEqual(
            AppModel.phase(after: .failure(.message("Line one\nline two")), stale: nil),
            .failed(message: "Line one", stale: nil)
        )
        let snapshot = UsageSnapshot(provider: .claude, fetchedAt: start, meters: [])
        XCTAssertEqual(AppModel.phase(after: .success(snapshot), stale: nil), .loaded(snapshot))
        XCTAssertEqual(AppModel.phase(after: .failure(.rateLimited), stale: snapshot), .failed(message: "Too many requests. Try again in a little while.", stale: snapshot))
    }
}
