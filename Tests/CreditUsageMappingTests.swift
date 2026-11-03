import XCTest
@testable import AIUsageWidget

final class CreditUsageMappingTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testOpenRouterKeyLimitBudgetAndFreeModels() throws {
        let json = """
        {"data":{"limit":100,"limit_remaining":74.5,"limit_reset":"monthly","usage_daily":1.2,"effective_budget":{"limit_usd":50,"spend_usd":32.5,"reset_interval":"weekly"},"free_model_daily_requests":{"limit":50,"used":12,"remaining":38}}}
        """
        let snapshot = try OpenRouterUsageMapping.snapshot(from: Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.id), ["key-limit", "budget", "free-models"])
        XCTAssertEqual(snapshot.meters[0].caption, "$25.50 of $100.00 · monthly")
        XCTAssertEqual(snapshot.meters[0].fraction ?? -1, 0.255, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.meters[1].fraction ?? -1, 0.65, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.meters[2].caption, "12 of 50 today")
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.65, accuracy: 0.000_001)
        XCTAssertNil(snapshot.note)
    }

    func testOpenRouterWithoutACapShowsSpend() throws {
        let json = """
        {"data":{"limit":null,"limit_remaining":null,"usage_daily":1.2,"usage_weekly":4,"usage_monthly":9}}
        """
        let snapshot = try OpenRouterUsageMapping.snapshot(from: Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
        XCTAssertEqual(snapshot.note, "No spend cap. $1.20 today · $4.00 this week · $9.00 this month")
    }

    func testDeepSeekPrefersUSDAndSkipsAMeter() throws {
        let json = """
        {"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"10","granted_balance":"0","topped_up_balance":"10"},{"currency":"USD","total_balance":"12.34","granted_balance":"2","topped_up_balance":"10.34"}]}
        """
        let snapshot = try DeepSeekUsageMapping.snapshot(from: Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
        XCTAssertEqual(snapshot.note, "$12.34 remaining · $2.00 granted · $10.34 topped up")
    }

    func testDeepSeekUnavailableBalance() throws {
        let json = """
        {"is_available":false,"balance_infos":[{"currency":"CNY","total_balance":"0.00","granted_balance":"0","topped_up_balance":"0"}]}
        """
        let snapshot = try DeepSeekUsageMapping.snapshot(from: Data(json.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.note, "¥0.00 remaining · not usable for API calls")
    }

    func testMoonshotBalanceAndDebt() throws {
        let json = """
        {"code":0,"data":{"available_balance":49.58894,"voucher_balance":46.58893,"cash_balance":3.00001},"status":true}
        """
        let snapshot = try MoonshotUsageMapping.snapshot(from: Data(json.utf8), currency: "USD", fetchedAt: fetchedAt)
        XCTAssertTrue(snapshot.meters.isEmpty)
        XCTAssertNil(snapshot.menuBarFraction)
        XCTAssertEqual(snapshot.note, "$49.59 available · $3.00 cash · $46.59 voucher")

        let debt = """
        {"code":0,"data":{"available_balance":0,"voucher_balance":0,"cash_balance":-1.5},"status":true}
        """
        let owed = try MoonshotUsageMapping.snapshot(from: Data(debt.utf8), currency: "CNY", fetchedAt: fetchedAt)
        XCTAssertEqual(owed.note, "¥0.00 available · owes ¥1.50 · add credits to call the API")
    }

    func testCreditPayloadsThatAreNotJSONThrow() {
        XCTAssertThrowsError(try OpenRouterUsageMapping.snapshot(from: Data("nope".utf8), fetchedAt: fetchedAt))
        XCTAssertThrowsError(try DeepSeekUsageMapping.snapshot(from: Data("{}".utf8), fetchedAt: fetchedAt))
        XCTAssertThrowsError(try MoonshotUsageMapping.snapshot(from: Data(#"{"code":1}"#.utf8), currency: "USD", fetchedAt: fetchedAt))
    }
}
