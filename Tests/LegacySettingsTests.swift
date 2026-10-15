import XCTest
@testable import AIUsageWidget

final class LegacySettingsTests: XCTestCase {
    private let oldSuite = "LegacySettingsTests.old"
    private let newSuite = "LegacySettingsTests.new"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: oldSuite)
        UserDefaults().removePersistentDomain(forName: newSuite)
        super.tearDown()
    }

    func testCopiesUserChoicesOnceAndLeavesSystemStateBehind() throws {
        let old = try XCTUnwrap(UserDefaults(suiteName: oldSuite))
        let new = try XCTUnwrap(UserDefaults(suiteName: newSuite))
        old.set(["claude", "grok"], forKey: AppModel.enabledSectionsKey)
        old.set([75, 90], forKey: AppModel.alertThresholdsKey)
        old.set(["claude.session": 75], forKey: AppModel.announcedAlertsKey)
        old.set(false, forKey: AppModel.showsProviderStatusKey)
        old.set(false, forKey: "NSStatusItem VisibleCC Item-0")
        old.set(Date(), forKey: "SULastCheckTime")

        LegacySettings.migrate(from: old, to: new)

        XCTAssertEqual(new.stringArray(forKey: AppModel.enabledSectionsKey), ["claude", "grok"])
        XCTAssertEqual(new.array(forKey: AppModel.alertThresholdsKey) as? [Int], [75, 90])
        XCTAssertEqual(new.dictionary(forKey: AppModel.announcedAlertsKey) as? [String: Int], ["claude.session": 75])
        XCTAssertEqual(new.object(forKey: AppModel.showsProviderStatusKey) as? Bool, false)
        XCTAssertNil(new.object(forKey: "NSStatusItem VisibleCC Item-0"))
        XCTAssertNil(new.object(forKey: "SULastCheckTime"))

        new.set(["codex"], forKey: AppModel.enabledSectionsKey)
        LegacySettings.migrate(from: old, to: new)
        XCTAssertEqual(new.stringArray(forKey: AppModel.enabledSectionsKey), ["codex"])
    }

    func testDoesNothingWithoutOldSettings() throws {
        let new = try XCTUnwrap(UserDefaults(suiteName: newSuite))
        LegacySettings.migrate(from: nil, to: new)
        XCTAssertNil(new.object(forKey: AppModel.enabledSectionsKey))
    }
}
