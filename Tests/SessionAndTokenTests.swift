import XCTest
@testable import AIUsageWidget

final class SessionAndTokenTests: XCTestCase {
    func testDatabaseURIIsReadOnly() {
        let uri = CursorSessionLocator.databaseURI(home: "/Users/demo")
        XCTAssertEqual(
            uri,
            "file:/Users/demo/Library/Application%20Support/Cursor/User/globalStorage/state.vscdb?mode=ro"
        )
        XCTAssertFalse(uri.contains("mode=rw"))
    }

    func testNormalizeTokenTrimsQuotesAndBlankValues() {
        XCTAssertEqual(CursorSessionLocator.normalizeToken("\"aaa.bbb.ccc\"\n"), "aaa.bbb.ccc")
        XCTAssertEqual(CursorSessionLocator.normalizeToken("plain-token"), "plain-token")
        XCTAssertNil(CursorSessionLocator.normalizeToken(" \n"))
    }

    func testLocalDatabaseTokenWinsOverSavedCookie() {
        XCTAssertEqual(
            CursorAccessTokenProvider.bearer(local: "local.token.value", saved: "WorkosCursorSessionToken=user_1::aaa.bbb.ccc"),
            "local.token.value"
        )
        XCTAssertEqual(CursorAccessTokenProvider.bearer(local: nil, saved: "aaa.bbb.ccc"), "aaa.bbb.ccc")
        XCTAssertEqual(
            CursorAccessTokenProvider.bearer(local: nil, saved: "WorkosCursorSessionToken=user_1::aaa.bbb.ccc"),
            "aaa.bbb.ccc"
        )
        XCTAssertEqual(
            CursorAccessTokenProvider.bearer(local: " ", saved: "WorkosCursorSessionToken=user_1%3A%3Aaaa.bbb.ccc"),
            "aaa.bbb.ccc"
        )
        XCTAssertNil(CursorAccessTokenProvider.bearer(local: nil, saved: "not a token"))
        XCTAssertNil(TokenShape.bearerToken(from: "a..c"))
        XCTAssertNil(TokenShape.bearerToken(from: "a.b"))
    }
}
