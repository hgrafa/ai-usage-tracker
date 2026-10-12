import XCTest
@testable import AIUsageWidget

final class CursorUsageMappingTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testPercentsAreTheSubscriptionPools() throws {
        let snapshot = try CursorUsageMapping.snapshot(from: Data(Self.percents.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Cursor models", "Other models"])
        XCTAssertEqual(snapshot.meters.map(\.caption), ["47% used", "12% used"])
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.47, accuracy: 0.000_001)
        XCTAssertNil(snapshot.breakdown)
        XCTAssertNil(snapshot.note)
        XCTAssertFalse(snapshot.meters.contains { $0.caption.contains("$") })
    }

    func testProPlusCreditIsNotShownBesidePercentPools() throws {
        let snapshot = try CursorUsageMapping.snapshot(from: Data(Self.proPlus.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Cursor models", "Other models"])
        XCTAssertEqual(snapshot.meters.map(\.caption), ["7% used", "0% used"])
        XCTAssertEqual(snapshot.meters[0].fraction ?? -1, 0.07, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.meters[1].fraction ?? -1, 0, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.07, accuracy: 0.000_001)
        XCTAssertNil(snapshot.breakdown)
        XCTAssertNil(snapshot.note)
        let rendered = snapshot.meters.map(\.caption).joined(separator: " ")
        XCTAssertFalse(rendered.contains("70"))
        XCTAssertFalse(rendered.contains("hit your usage limit"))
    }

    func testIncludedFractionWhenPercentsAreMissing() throws {
        let snapshot = try CursorUsageMapping.snapshot(from: Data(Self.includedOnly.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Included"])
        XCTAssertEqual(snapshot.meters.first?.caption, "$5.00 of $20.00")
        XCTAssertEqual(snapshot.meters.first?.fraction ?? -1, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.25, accuracy: 0.000_001)
        XCTAssertNil(snapshot.breakdown)
    }

    func testOnDemandMeterOnlyWhenThatLimitIsEnabled() throws {
        let enabled = try CursorUsageMapping.snapshot(from: Data(Self.onDemand.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(enabled.meters.map(\.title), ["Included", "On-demand"])
        XCTAssertEqual(enabled.meters.map(\.caption), ["$4.90 of $70.00", "$2.00 of $50.00"])
        XCTAssertEqual(enabled.meters[0].fraction ?? -1, 0.07, accuracy: 0.000_001)
        XCTAssertEqual(enabled.meters[1].fraction ?? -1, 0.04, accuracy: 0.000_001)

        let disabled = try CursorUsageMapping.snapshot(from: Data(Self.onDemandDisabled.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(disabled.meters.map(\.title), ["Included"])
        XCTAssertEqual(disabled.meters.first?.caption, "$4.90 of $70.00")
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
      "displayMessage": "You've hit your usage limit",
      "planUsage": {
        "autoPercentUsed": 47,
        "apiPercentUsed": 12,
        "includedSpend": 2500,
        "limit": 2000,
        "totalSpend": 3000
      },
      "spendLimitUsage": {"individualUsed": 500, "individualLimit": 0}
    }
    """

    private static let proPlus = """
    {
      "displayMessage": "You've hit your usage limit",
      "planUsage": {
        "autoPercentUsed": 7,
        "apiPercentUsed": 0,
        "includedSpend": 7000,
        "limit": 7000
      }
    }
    """

    private static let includedOnly = """
    {"planUsage":{"includedSpend":500,"limit":2000}}
    """

    private static let onDemand = """
    {
      "planUsage": {"includedSpend": 490, "limit": 7000},
      "spendLimitUsage": {"individualUsed": 200, "individualLimit": 5000}
    }
    """

    private static let onDemandDisabled = """
    {
      "planUsage": {"includedSpend": 490, "limit": 7000},
      "spendLimitUsage": {"individualUsed": 0, "individualLimit": 0}
    }
    """

    private static let zeros = """
    {
      "planUsage": {"autoPercentUsed": 0, "includedSpend": 0},
      "spendLimitUsage": {"individualUsed": 0}
    }
    """
}
