import AppKit
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
        let image = MenuBarTitle.statusImage(for: readings)
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(image.size.width, 80)
        XCTAssertEqual(MenuBarLabel.valueTitle(percent: 0), "0%")
        XCTAssertEqual(MenuBarLabel.valueTitle(percent: 12), "12%")
        XCTAssertEqual(MenuBarLabel.valueTitle(percent: nil), "–")
        XCTAssertEqual(MenuBarLabel.valueTitle(percent: 80), "80%")
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

    func testOfficialMarksOccupyTheirViewBoxes() {
        let claude = ProviderGlyph.makePath(for: .claude).boundingBoxOfPath
        XCTAssertEqual(claude.minX, 0, accuracy: 0.6)
        XCTAssertEqual(claude.minY, 0, accuracy: 0.6)
        XCTAssertEqual(claude.width, 24, accuracy: 1)
        XCTAssertEqual(claude.height, 24, accuracy: 1)

        let codex = ProviderGlyph.makePath(for: .codex).boundingBoxOfPath
        XCTAssertEqual(codex.minX, 0, accuracy: 0.8)
        XCTAssertEqual(codex.minY, 0, accuracy: 0.8)
        XCTAssertEqual(codex.width, 24, accuracy: 1.2)
        XCTAssertEqual(codex.height, 24, accuracy: 1.2)

        let cursor = ProviderGlyph.makePath(for: .cursor).boundingBoxOfPath
        XCTAssertGreaterThan(cursor.width, 400)
        XCTAssertGreaterThan(cursor.height, 450)

        let grok = ProviderGlyph.makePath(for: .grok).boundingBoxOfPath
        XCTAssertEqual(grok.width, 21, accuracy: 0.5)
        XCTAssertEqual(grok.height, 21, accuracy: 0.5)
    }

    func testArcFollowsSVGSweep() {
        let box = SVGPathParser.path(from: "M0 0 A1 1 0 0 1 2 0").boundingBoxOfPath
        XCTAssertEqual(box.midX, 1, accuracy: 0.08)
        XCTAssertEqual(box.minY, -1, accuracy: 0.08)
        XCTAssertEqual(box.maxY, 0, accuracy: 0.08)
    }

    func testFittedMarksStayInsideTheMenuBarSlot() {
        let rect = CGRect(x: 0, y: 0, width: 15, height: 15)
        for provider in ProviderID.allCases {
            let box = ProviderGlyph.fittedPath(for: provider, in: rect).boundingBoxOfPath
            XCTAssertGreaterThanOrEqual(box.minX, -0.05, provider.rawValue)
            XCTAssertGreaterThanOrEqual(box.minY, -0.05, provider.rawValue)
            XCTAssertLessThanOrEqual(box.maxX, 15.05, provider.rawValue)
            XCTAssertLessThanOrEqual(box.maxY, 15.05, provider.rawValue)
        }
    }

    @MainActor
    func testMarksKeepShape() {
        for provider in ProviderID.allCases {
            let plain = opaqueFraction(bitmap(for: provider))
            XCTAssertGreaterThan(plain, 0.12, provider.rawValue)
            XCTAssertLessThan(plain, 0.9, provider.rawValue)
        }

        XCTAssertTrue(containsPixel(in: bitmap(for: .codex)) { _, _, _, alpha in alpha < 0.2 })
        XCTAssertTrue(containsPixel(in: bitmap(for: .cursor)) { _, _, _, alpha in alpha < 0.2 })
        XCTAssertTrue(containsPixel(in: bitmap(for: .grok)) { _, _, _, alpha in alpha < 0.2 })
    }

    @MainActor
    private func bitmap(for provider: ProviderID, side: Int = 64) -> NSBitmapImageRep {
        let image = ProviderMarkImage.makeImage(for: provider, side: CGFloat(side))
        image.isTemplate = false
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private func opaqueFraction(_ rep: NSBitmapImageRep) -> Double {
        let total = rep.pixelsWide * rep.pixelsHigh
        guard total > 0 else { return 0 }
        var opaque = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                    opaque += 1
                }
            }
        }
        return Double(opaque) / Double(total)
    }

    private func containsPixel(
        in rep: NSBitmapImageRep,
        where matches: (CGFloat, CGFloat, CGFloat, CGFloat) -> Bool
    ) -> Bool {
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if matches(color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent) {
                    return true
                }
            }
        }
        return false
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

    func testProviderOrderDefaultsAndKeepsNewProviders() {
        XCTAssertEqual(ProviderOrder(stored: nil).providers, ProviderID.allCases)
        let saved = ProviderOrder(stored: ["moonshot", "nope", "claude", "claude"])
        XCTAssertEqual(
            saved.providers,
            [.moonshot, .claude, .codex, .cursor, .grok, .openrouter, .deepseek]
        )
        XCTAssertEqual(
            Array(saved.moving(from: IndexSet(integer: 0), to: 2).providers.prefix(3)),
            [.claude, .moonshot, .codex]
        )
        XCTAssertEqual(ProviderOrder.standard.visible([.grok, .claude]), [.claude, .grok])
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
