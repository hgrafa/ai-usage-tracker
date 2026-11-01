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

    func testMenuBarOrderFollowsASettingsDrag() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let model = AppModel(defaults: defaults)
        let moonshot = try XCTUnwrap(model.providerOrder.firstIndex(of: .moonshot))
        model.moveProviders(from: IndexSet(integer: moonshot), to: 0)
        XCTAssertEqual(model.providerOrder.first, .moonshot)
        XCTAssertEqual(model.visibleProviders.first, .moonshot)
        XCTAssertEqual(AppModel(defaults: defaults).visibleProviders.first, .moonshot)
    }

    func testAHiddenProviderStaysOutOfTheMenuBar() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let model = AppModel(defaults: defaults)
        model.setSectionEnabled(.claude, enabled: false)
        XCTAssertEqual(model.visibleProviders.first, .codex)
        XCTAssertFalse(model.visibleProviders.contains(.claude))
    }
}
