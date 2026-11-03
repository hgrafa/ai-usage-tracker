import XCTest
@testable import AIUsageWidget

final class BundleReplacementTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("bundle-replace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSameOrMissingBundleIsNotAReplacement() {
        let running = BundleFileID(device: 1, inode: 2)
        XCTAssertFalse(BundleReplacement.shouldRelaunch(running: running, pathNow: running, isBundle: true))
        XCTAssertFalse(BundleReplacement.shouldRelaunch(running: running, pathNow: nil, isBundle: true))
        XCTAssertFalse(BundleReplacement.shouldRelaunch(
            running: running,
            pathNow: BundleFileID(device: 1, inode: 3),
            isBundle: false
        ))
    }

    func testReplacedPathIsADifferentBundle() throws {
        let app = root.appendingPathComponent("AI Usage.app")
        try makeApp(app)
        let running = try XCTUnwrap(BundleFileID.at(app))
        XCTAssertTrue(BundleReplacement.isAppBundle(app))
        XCTAssertFalse(BundleReplacement.shouldRelaunch(
            running: running,
            pathNow: BundleFileID.at(app),
            isBundle: true
        ))

        let aside = root.appendingPathComponent("Previous.app")
        try FileManager.default.moveItem(at: app, to: aside)
        XCTAssertFalse(BundleReplacement.shouldRelaunch(
            running: running,
            pathNow: BundleFileID.at(app),
            isBundle: BundleReplacement.isAppBundle(app)
        ))

        let incoming = root.appendingPathComponent("Incoming.app")
        try makeApp(incoming)
        try FileManager.default.moveItem(at: incoming, to: app)
        XCTAssertTrue(BundleReplacement.shouldRelaunch(
            running: running,
            pathNow: BundleFileID.at(app),
            isBundle: BundleReplacement.isAppBundle(app)
        ))
    }

    @MainActor
    func testWatcherRelaunchesWhenTheInstallPathIsReplaced() throws {
        let app = root.appendingPathComponent("AI Usage.app")
        try makeApp(app)
        let relaunched = expectation(description: "relaunch")
        let watcher = try XCTUnwrap(BundleReplacementWatcher(bundleURL: app) { url in
            XCTAssertEqual(url.standardizedFileURL.path, app.standardizedFileURL.path)
            relaunched.fulfill()
        })
        defer { watcher.stop() }

        let incoming = root.appendingPathComponent("Incoming.app")
        try makeApp(incoming)
        _ = try FileManager.default.replaceItemAt(app, withItemAt: incoming)
        wait(for: [relaunched], timeout: 3)
    }

    @MainActor
    func testWatcherStaysQuietWhenTheBundleIsOnlyRemoved() throws {
        let app = root.appendingPathComponent("AI Usage.app")
        try makeApp(app)
        let relaunched = expectation(description: "relaunch")
        relaunched.isInverted = true
        let watcher = try XCTUnwrap(BundleReplacementWatcher(bundleURL: app) { _ in
            relaunched.fulfill()
        })
        defer { watcher.stop() }
        try FileManager.default.removeItem(at: app)
        wait(for: [relaunched], timeout: 1)
    }

    private func makeApp(_ url: URL) throws {
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: contents.appendingPathComponent("Info.plist").path, contents: Data()))
    }
}
