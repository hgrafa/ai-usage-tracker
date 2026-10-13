import XCTest
@testable import AIUsageWidget

final class AppUpdateTests: XCTestCase {
    func testVersionDropsTagPrefixAndWhitespace() {
        XCTAssertEqual(AppUpdate.normalize("v1.2.3"), "1.2.3")
        XCTAssertEqual(AppUpdate.normalize(" V0.1.0\n"), "0.1.0")
        XCTAssertEqual(AppUpdate.normalize("1.0"), "1.0")
    }

    func testBundleDeclaresTheSparkleFeedAndKey() throws {
        let bundle = Bundle(for: AppModel.self)
        let feed = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String)
        XCTAssertEqual(feed, "https://github.com/hgrafa/ai-usage-tracker/releases/latest/download/appcast.xml")
        let key = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
        XCTAssertEqual(Data(base64Encoded: key)?.count, 32)
    }
}
