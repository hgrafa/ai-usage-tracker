import XCTest
@testable import AIUsageWidget

final class CursorUsageMappingTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testPercentsAreMetersAndSpendIsBreakdown() throws {
        let snapshot = try CursorUsageMapping.snapshot(from: Data(Self.percents.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Cursor models", "Other models"])
        XCTAssertEqual(snapshot.meters.map(\.caption), ["47% used", "12% used"])
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.47, accuracy: 0.000_001)
        let breakdown = try XCTUnwrap(snapshot.breakdown)
        XCTAssertEqual(breakdown.headline, "Resets on Nov 1")
        XCTAssertEqual(breakdown.segments.map(\.title), ["Included", "On-demand"])
        XCTAssertEqual(breakdown.segments.map(\.displayValue), ["$25.00", "$5.00"])
        XCTAssertEqual(breakdown.segments.map(\.amount), [25.0, 5.0])
        XCTAssertFalse(snapshot.meters.contains { $0.caption.contains("$") })
        XCTAssertFalse(breakdown.segments.contains { $0.title == "Cursor models" || $0.title == "Other models" })
    }

    func testIncludedFractionWhenPercentsAreMissing() throws {
        let snapshot = try CursorUsageMapping.snapshot(from: Data(Self.includedOnly.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Included"])
        XCTAssertEqual(snapshot.meters.first?.caption, "25% used")
        XCTAssertEqual(snapshot.meters.first?.fraction ?? -1, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.breakdown?.segments.map(\.title), ["Included"])
        XCTAssertEqual(snapshot.breakdown?.segments.first?.displayValue, "$5.00")
    }

    func testZeroSpendDoesNotDrawABreakdown() throws {
        let snapshot = try CursorUsageMapping.snapshot(from: Data(Self.zeros.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.caption), ["0% used"])
        XCTAssertEqual(snapshot.menuBarFraction, 0.0)
        XCTAssertNil(snapshot.breakdown)
    }

    func testZeroLimitDoesNotDivide() throws {
        let snapshot = try CursorUsageMapping.snapshot(from: Data(#"{"planUsage":{"includedSpend":10,"limit":0}}"#.utf8), fetchedAt: fetchedAt)
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
    }

    func testMalformedPayload() {
        XCTAssertThrowsError(try CursorUsageMapping.snapshot(from: Data("not-json".utf8), fetchedAt: fetchedAt)) { error in
            XCTAssertEqual(error as? UsageFetchError, .malformed)
        }
    }

    func testBearerRequestHasNoQueryToken() throws {
        let request = CursorDashboardRequests.request(url: CursorDashboardRequests.periodUsage, token: "aaa.bbb.ccc")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, Data("{}".utf8))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer aaa.bbb.ccc")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Connect-Protocol-Version"), "1")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.url?.path, "/aiserver.v1.DashboardService/GetCurrentPeriodUsage")
        XCTAssertEqual(CursorDashboardRequests.sandUsage.path, "/aiserver.v1.DashboardService/GetSandUsageStatus")
    }

    private static let percents = """
    {
      "displayMessage": "Resets on Nov 1",
      "planUsage": {
        "autoPercentUsed": 47,
        "apiPercentUsed": 12,
        "includedSpend": 2500,
        "limit": 2000,
        "totalSpend": 3000
      },
      "spendLimitUsage": {"individualUsed": 500}
    }
    """

    private static let includedOnly = """
    {"planUsage":{"includedSpend":500,"limit":2000}}
    """

    private static let zeros = """
    {
      "planUsage": {"autoPercentUsed": 0, "includedSpend": 0},
      "spendLimitUsage": {"individualUsed": 0}
    }
    """
}
