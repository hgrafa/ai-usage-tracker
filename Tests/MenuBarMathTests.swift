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
