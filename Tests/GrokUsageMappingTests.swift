import XCTest
@testable import AIUsageWidget

final class GrokUsageMappingTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testWeeklyMeterWhenAllowanceExists() throws {
        let json = """
        {"hasNonZeroIncludedLimit": true, "usagePercent": 40, "usesPooledEnterpriseAllowance": false, "nextResetTimestampUtc": 1790000000000}
        """
        let snapshot = try GrokUsageMapping.snapshot(from: Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Weekly"])
        XCTAssertEqual(snapshot.meters.first?.caption.hasPrefix("40% used"), true)
        XCTAssertTrue(snapshot.meters.first?.caption.contains("resets") == true)
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.40, accuracy: 0.000_001)
        XCTAssertNil(snapshot.note)
        XCTAssertNil(snapshot.breakdown)
    }

    func testAbsentLimitFlagStillShowsUsage() throws {
        let snapshot = try GrokUsageMapping.snapshot(
            from: Data(#"{"usagePercent":10}"#.utf8),
            fetchedAt: fetchedAt
        )
        XCTAssertEqual(snapshot.meters.count, 1)
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.10, accuracy: 0.000_001)
    }

    func testNoIncludedLimitHasNoFakeBar() throws {
        let snapshot = try GrokUsageMapping.snapshot(
            from: Data(#"{"hasNonZeroIncludedLimit": false, "usagePercent": 0}"#.utf8),
            fetchedAt: fetchedAt
        )
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
        XCTAssertEqual(snapshot.note, "No Grok Bot allowance on this account.")
    }

    func testPooledAllowanceDoesNotDrawAMeter() throws {
        let snapshot = try GrokUsageMapping.snapshot(
            from: Data(#"{"hasNonZeroIncludedLimit": true, "usagePercent": 40, "usesPooledEnterpriseAllowance": true}"#.utf8),
            fetchedAt: fetchedAt
        )
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
        XCTAssertNil(snapshot.note)
    }

    func testMalformedDoesNotCrash() {
        XCTAssertThrowsError(try GrokUsageMapping.snapshot(from: Data("not-json".utf8), fetchedAt: fetchedAt)) { error in
            XCTAssertEqual(error as? UsageFetchError, .malformed)
        }
        XCTAssertNoThrow(try GrokUsageMapping.snapshot(from: Data("{}".utf8), fetchedAt: fetchedAt))
    }
}
