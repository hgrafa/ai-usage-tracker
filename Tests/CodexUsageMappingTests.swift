import XCTest
@testable import AIUsageWidget

final class CodexUsageMappingTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_789_000_000)

    func testPrefersCodexBucketAndSkipsNullSecondary() throws {
        let snapshot = try CodexUsageMapping.snapshot(from: Data(Self.preferred.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Session (5 hour)"])
        XCTAssertEqual(snapshot.meters.first?.fraction ?? -1, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.meters.first?.caption.hasPrefix("25% used"), true)
        XCTAssertTrue(snapshot.meters.first?.caption.contains("resets") == true)
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.25, accuracy: 0.000_001)
        XCTAssertNil(snapshot.breakdown)
    }

    func testBothWindowsAreMetersNotABreakdown() throws {
        let snapshot = try CodexUsageMapping.snapshot(from: Data(Self.bothWindows.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Session (5 hour)", "Weekly (7 day)"])
        XCTAssertEqual(snapshot.menuBarFraction ?? -1, 0.80, accuracy: 0.000_001)
        XCTAssertNil(snapshot.breakdown)
    }

    func testWindowTitles() throws {
        XCTAssertEqual(CodexUsageMapping.windowTitle(minutes: 300), "Session (5 hour)")
        XCTAssertEqual(CodexUsageMapping.windowTitle(minutes: 10080), "Weekly (7 day)")
        XCTAssertEqual(CodexUsageMapping.windowTitle(minutes: 15), "Window (15 min)")
        XCTAssertEqual(CodexUsageMapping.windowTitle(minutes: nil), "Usage")
        let snapshot = try CodexUsageMapping.snapshot(from: Data(Self.nullDuration.utf8), fetchedAt: fetchedAt)
        XCTAssertEqual(snapshot.meters.map(\.title), ["Usage"])
    }

    func testParserIgnoresNotificationsAndHidesRPCErrors() throws {
        let lines = [
            #"{"method":"account/updated","params":{"token":"supersecretvalue"}}"#,
            #"{"id":0,"result":{"ok":true}}"#,
            #"{"id":1,"result":{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300}}}}"#
        ]
        let data = try XCTUnwrap(CodexStdoutParser.successResult(in: Data(lines.joined(separator: "\n").utf8)))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("supersecretvalue"))
        XCTAssertTrue(text.contains("usedPercent"))
        XCTAssertFalse(CodexStdoutParser.sawFailure(in: Data(lines.joined(separator: "\n").utf8)))

        let failure = Data(#"{"id":1,"error":{"message":"token supersecretvalue"}}"#.utf8)
        XCTAssertTrue(CodexStdoutParser.sawFailure(in: failure))
        XCTAssertNil(CodexStdoutParser.successResult(in: failure))
        XCTAssertFalse(CodexAppServerClient.notLoggedInMessage.contains("supersecretvalue"))

        XCTAssertNil(CodexStdoutParser.successResult(in: Data(#"{"id":1"#.utf8)))
        XCTAssertFalse(CodexStdoutParser.sawFailure(in: Data(#"{"id":1"#.utf8)))
    }

    func testExecutableLookupOrder() {
        let homebrew = CodexExecutable.resolve(pathEnvironment: "/usr/bin:/bin", isExecutable: { $0 == "/opt/homebrew/bin/codex" })
        XCTAssertEqual(homebrew?.path, "/opt/homebrew/bin/codex")

        let onPath = CodexExecutable.resolve(
            pathEnvironment: "/custom/bin:/usr/bin",
            isExecutable: { $0 == "/custom/bin/codex" || $0 == "/opt/homebrew/bin/codex" }
        )
        XCTAssertEqual(onPath?.path, "/custom/bin/codex")

        let local = CodexExecutable.resolve(pathEnvironment: "/usr/bin", isExecutable: { $0 == "/usr/local/bin/codex" })
        XCTAssertEqual(local?.path, "/usr/local/bin/codex")
        XCTAssertNil(CodexExecutable.resolve(pathEnvironment: "/usr/bin", isExecutable: { _ in false }))
    }

    private static let preferred = """
    {
      "rateLimits": {
        "primary": {"usedPercent": 99, "windowDurationMins": 300, "resetsAt": 1790000000}
      },
      "rateLimitsByLimitId": {
        "codex": {
          "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1790000000},
          "secondary": null
        }
      }
    }
    """

    private static let bothWindows = """
    {
      "rateLimits": {
        "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1790000000},
        "secondary": {"usedPercent": 80, "windowDurationMins": 10080, "resetsAt": 1790001000}
      }
    }
    """

    private static let nullDuration = """
    {"rateLimits":{"primary":{"usedPercent":5,"windowDurationMins":null}}}
    """
}
