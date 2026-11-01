import XCTest
@testable import AIUsageWidget

final class LimitAlertTests: XCTestCase {
    func testThresholdsDefaultToNoneAndDropUnknownValues() {
        XCTAssertTrue(AlertThresholds(stored: nil).values.isEmpty)
        let thresholds = AlertThresholds(stored: [90, 33, 50, 90])
        XCTAssertEqual(thresholds.values, [50, 90])
        XCTAssertEqual(thresholds.stored, [50, 90])
    }

    func testAnnouncesHighestCrossedThresholdOnce() {
        var tracker = LimitAlertTracker()
        let thresholds: Set<Int> = [50, 75, 90]

        XCTAssertTrue(tracker.alerts(for: snapshot(.claude, session: 0.40), thresholds: thresholds).isEmpty)

        let first = tracker.alerts(for: snapshot(.claude, session: 0.80), thresholds: thresholds)
        XCTAssertEqual(first.map(\.threshold), [75])
        XCTAssertEqual(first.first?.provider, .claude)
        XCTAssertEqual(first.first?.title, "Claude at 75%")
        XCTAssertEqual(first.first?.body, "Session · 80% used")

        XCTAssertTrue(tracker.alerts(for: snapshot(.claude, session: 0.85), thresholds: thresholds).isEmpty)
        XCTAssertEqual(tracker.alerts(for: snapshot(.claude, session: 0.91), thresholds: thresholds).map(\.threshold), [90])
        XCTAssertTrue(tracker.alerts(for: snapshot(.claude, session: 1.0), thresholds: thresholds).isEmpty)
    }

    func testAnnouncesAgainAfterTheLimitResets() {
        var tracker = LimitAlertTracker()
        let thresholds: Set<Int> = [90]
        XCTAssertEqual(tracker.alerts(for: snapshot(.codex, session: 0.95), thresholds: thresholds).count, 1)
        XCTAssertTrue(tracker.alerts(for: snapshot(.codex, session: 0.05), thresholds: thresholds).isEmpty)
        XCTAssertTrue(tracker.announced.isEmpty)
        XCTAssertEqual(tracker.alerts(for: snapshot(.codex, session: 0.92), thresholds: thresholds).count, 1)
    }

    func testTracksEachMeterSeparately() {
        var tracker = LimitAlertTracker()
        let usage = UsageSnapshot(
            provider: .claude,
            fetchedAt: Date(timeIntervalSince1970: 1_790_000_000),
            meters: [
                Meter(id: "session", title: "Session", fraction: 0.92, caption: "92% used"),
                Meter(id: "weekly", title: "Weekly", fraction: 0.55, caption: "55% used"),
                Meter(id: "none", title: "No data", fraction: nil, caption: "")
            ]
        )
        let alerts = tracker.alerts(for: usage, thresholds: [50, 90])
        XCTAssertEqual(alerts.map(\.meterID), ["session", "weekly"])
        XCTAssertEqual(alerts.map(\.threshold), [90, 50])
    }

    func testNoThresholdsMeansNoAlertsAndClearsHistory() {
        var tracker = LimitAlertTracker(announced: ["claude.session": 90])
        XCTAssertTrue(tracker.alerts(for: snapshot(.claude, session: 0.95), thresholds: []).isEmpty)
        XCTAssertTrue(tracker.announced.isEmpty)
    }

    func testRemembersAnnouncementsAcrossLaunches() {
        var tracker = LimitAlertTracker(announced: ["cursor.session": 75])
        XCTAssertTrue(tracker.alerts(for: snapshot(.cursor, session: 0.80), thresholds: [75, 90]).isEmpty)
    }

    private func snapshot(_ provider: ProviderID, session fraction: Double) -> UsageSnapshot {
        UsageSnapshot(
            provider: provider,
            fetchedAt: Date(timeIntervalSince1970: 1_790_000_000),
            meters: [Meter(id: "session", title: "Session", fraction: fraction, caption: "\(Int((fraction * 100).rounded()))% used")]
        )
    }
}
