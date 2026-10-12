import XCTest
@testable import AIUsageWidget

final class MenuBarMathTests: XCTestCase {
    func testMaxPercentAcrossLoadedAndStaleSnapshots() {
        let phases: [ProviderID: ProviderPhase] = [
            .claude: .failed(message: "offline", stale: snapshot(.claude, fraction: 0.25)),
            .codex: .unconfigured,
            .cursor: .loaded(snapshot(.cursor, fraction: 91.0 / 100)),
            .grok: .loading(stale: snapshot(.grok, fraction: 0.10))
        ]
        XCTAssertEqual(MenuBarMath.percent(from: phases), 91)
    }

    func testZeroPercentIsShown() {
        let phases: [ProviderID: ProviderPhase] = [
            .cursor: .loaded(snapshot(.cursor, fraction: 0))
        ]
        XCTAssertEqual(MenuBarMath.percent(from: phases), 0)
        XCTAssertEqual(MenuBarLabel.title(percent: 0), "0%")
        XCTAssertNil(MenuBarLabel.title(percent: nil))
        XCTAssertEqual(MenuBarLabel.valueTitle(percent: nil), "–")
    }

    func testMenuBarShowsEachVisibleProvider() {
        let phases: [ProviderID: ProviderPhase] = [
            .claude: .loaded(snapshot(.claude, fraction: 0)),
            .codex: .loaded(snapshot(.codex, fraction: 0.42)),
            .cursor: .loaded(snapshot(.cursor, fraction: 0.91)),
            .grok: .failed(message: "offline", stale: snapshot(.grok, fraction: 0.1))
        ]
        let readings = MenuBarMath.readings(in: phases, visible: [.claude, .codex, .grok])
        XCTAssertEqual(readings.map(\.provider), [.claude, .codex, .grok])
        XCTAssertEqual(readings.map(\.percent), [0, 42, 10])
        XCTAssertEqual(MenuBarLabel.itemLabel(readings[0]), "Claude 0 percent")
        XCTAssertEqual(MenuBarLabel.itemLabel(MenuBarReading(provider: .cursor, percent: nil)), "Cursor, no reading")
    }

    @MainActor
    func testMenuBarTitleKeepsEveryIconAndPercent() {
        let readings = [
            MenuBarReading(provider: .claude, percent: 0),
            MenuBarReading(provider: .codex, percent: 12),
            MenuBarReading(provider: .cursor, percent: nil),
            MenuBarReading(provider: .grok, percent: 80)
        ]
        let title = MenuBarTitle.attributedTitle(for: readings)
        let raw = title.string
        XCTAssertEqual(raw.components(separatedBy: "\u{FFFC}").count - 1, 4)
        XCTAssertTrue(raw.contains("0%"))
        XCTAssertTrue(raw.contains("12%"))
        XCTAssertTrue(raw.contains("–"))
        XCTAssertTrue(raw.contains("80%"))
        XCTAssertGreaterThan(MenuBarTitle.statusLength(for: title), 80)
    }

    func testNilWhenNoRealFraction() {
        let phases: [ProviderID: ProviderPhase] = [
            .claude: .loaded(snapshot(.claude, fraction: nil)),
            .codex: .failed(message: "offline", stale: nil),
            .cursor: .unconfigured
        ]
        XCTAssertNil(MenuBarMath.percent(from: phases))
        XCTAssertNil(MenuBarMath.percent(from: []))
    }

    func testRoundsAndClamps() {
        XCTAssertEqual(MenuBarMath.percent(from: [snapshot(.claude, fraction: 0.5)]), 50)
        XCTAssertEqual(MenuBarMath.percent(from: [snapshot(.claude, fraction: 0.476)]), 48)
        XCTAssertEqual(MenuBarMath.percent(from: [snapshot(.claude, fraction: 0.474)]), 47)
        XCTAssertEqual(MenuBarMath.percent(from: [snapshot(.claude, fraction: 1.4)]), 100)
        XCTAssertEqual(MenuBarMath.percent(from: [snapshot(.claude, fraction: -0.2)]), 0)
        XCTAssertEqual(MenuBarMath.percent(from: [snapshot(.claude, fraction: UsageFormatting.clampedFraction(percent: 47))]), 47)
    }

    func testIgnoresNilFractionWhenAnotherValueExists() {
        let snapshots = [
            snapshot(.claude, fraction: nil),
            snapshot(.cursor, fraction: 0.25)
        ]
        XCTAssertEqual(MenuBarMath.percent(from: snapshots), 25)
    }

    func testEnabledSectionsDefaultsToAllWhenUnset() {
        let sections = EnabledSections(stored: nil)
        XCTAssertEqual(sections.providers, Set(ProviderID.allCases))
    }

    func testEnabledSectionsKeepsAnEmptyChoice() {
        let sections = EnabledSections(stored: [])
        XCTAssertTrue(sections.providers.isEmpty)
        XCTAssertEqual(sections.stored, [])
    }

    func testEnabledSectionsDropsUnknownNames() {
        let sections = EnabledSections(stored: ["claude", "nope", "grok"])
        XCTAssertEqual(sections.providers, [.claude, .grok])
        XCTAssertEqual(sections.stored, ["claude", "grok"])
    }

    func testHeatThresholds() {
        XCTAssertEqual(MeterHeat.level(for: 0), .low)
        XCTAssertEqual(MeterHeat.level(for: 0.699), .low)
        XCTAssertEqual(MeterHeat.level(for: 0.70), .warm)
        XCTAssertEqual(MeterHeat.level(for: 0.899), .warm)
        XCTAssertEqual(MeterHeat.level(for: 0.90), .hot)
    }

    func testUsedCaptionAndResetHint() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let reset = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertEqual(UsageFormatting.usedCaption(percent: 47, resetsAt: nil, now: now), "47% used")
        let caption = UsageFormatting.usedCaption(percent: 25, resetsAt: reset, now: now)
        XCTAssertTrue(caption.hasPrefix("25% used · resets "))
        XCTAssertEqual(UsageFormatting.clampedFraction(percent: 140), 1)
        XCTAssertEqual(UsageFormatting.usedCaption(percent: 140, resetsAt: nil, now: now), "140% used")
        XCTAssertEqual(UsageFormatting.dollars(cents: 2500), "$25.00")
    }

    private func snapshot(_ provider: ProviderID, fraction: Double?) -> UsageSnapshot {
        UsageSnapshot(provider: provider, fetchedAt: Date(timeIntervalSince1970: 1_790_000_000), meters: [], menuBarFraction: fraction)
    }
}
