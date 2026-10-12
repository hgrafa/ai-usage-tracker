import XCTest
@testable import AIUsageWidget

final class StatusPageTests: XCTestCase {
    func testClaudePageKeepsTheOfficialWordingAndAffectedComponent() throws {
        let health = try XCTUnwrap(StatusPageMapping.claude(from: Data(Self.claude.utf8)))
        XCTAssertEqual(health.level, .degraded)
        XCTAssertEqual(health.level.word, "Degraded")
        XCTAssertTrue(health.level.reportsTrouble)
        XCTAssertFalse(ServiceLevel.operational.reportsTrouble)
        XCTAssertFalse(ServiceLevel.unknown.reportsTrouble)
        XCTAssertEqual(health.title, "Partially Degraded Service")
        XCTAssertEqual(health.affected, ["Claude Console"])
        XCTAssertEqual(health.detail, "Partially Degraded Service. Affects Claude Console")
    }

    func testCodexUsesOnlyCodexComponents() throws {
        let health = try XCTUnwrap(StatusPageMapping.codex(from: Data(Self.openai.utf8)))
        XCTAssertEqual(health.level, .major)
        XCTAssertEqual(health.level.word, "Down")
        XCTAssertEqual(health.affected, ["Codex API"])
        XCTAssertFalse(health.components.contains { $0.name == "Chat Completions" })
    }

    func testCursorAndGrokAreSplit() throws {
        let pair = try XCTUnwrap(StatusPageMapping.cursorAndGrok(from: Data(Self.cursor.utf8)))
        XCTAssertEqual(pair.cursor.level, .operational)
        XCTAssertEqual(pair.cursor.level.word, "Clear")
        XCTAssertTrue(pair.cursor.affected.isEmpty)
        XCTAssertEqual(pair.grok.level, .degraded)
        XCTAssertEqual(pair.grok.level.word, "Degraded")
        XCTAssertEqual(pair.grok.affected, ["Grok Bot"])
    }

    private static let claude = """
    {
      "status": {"indicator": "minor", "description": "Partially Degraded Service"},
      "components": [
        {"id": "ai", "name": "claude.ai", "status": "operational"},
        {"id": "console", "name": "Claude Console (platform.claude.com)", "status": "degraded_performance"}
      ]
    }
    """

    private static let openai = """
    {
      "components": [
        {"name": "Chat Completions", "status": "operational"},
        {"name": "Codex Web", "status": "operational"},
        {"name": "Codex API", "status": "major_outage"}
      ]
    }
    """

    private static let cursor = """
    {
      "status": {"indicator": "minor", "description": "Partially Degraded Service"},
      "components": [
        {"name": "IDE", "status": "operational"},
        {"name": "Grok Bot", "status": "degraded_performance"}
      ]
    }
    """
}
