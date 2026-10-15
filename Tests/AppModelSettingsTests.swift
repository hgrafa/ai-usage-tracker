import XCTest
@testable import AIUsageWidget

@MainActor
final class AppModelSettingsTests: XCTestCase {
    private let suiteName = "AppModelSettingsTests"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testProviderStatusIsShownByDefaultAndRemembered() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        XCTAssertTrue(AppModel(defaults: defaults).showsProviderStatus)

        AppModel(defaults: defaults).showsProviderStatus = false
        XCTAssertFalse(AppModel(defaults: defaults).showsProviderStatus)
    }
}
