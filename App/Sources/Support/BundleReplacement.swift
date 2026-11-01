import AppKit
import Darwin
import Foundation

struct BundleFileID: Equatable, Sendable {
    var device: Int32
    var inode: UInt64

    static func at(_ url: URL) -> BundleFileID? {
        var info = stat()
        let rc = url.path.withCString { stat($0, &info) }
        guard rc == 0 else { return nil }
        return BundleFileID(device: info.st_dev, inode: info.st_ino)
    }

    static func of(descriptor: Int32) -> BundleFileID? {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { return nil }
        return BundleFileID(device: info.st_dev, inode: info.st_ino)
    }
}

enum BundleReplacement {
    /// Finder Replace renames the running bundle away and puts the new app at the same path.
    static func shouldRelaunch(running: BundleFileID, pathNow: BundleFileID?, isBundle: Bool) -> Bool {
        guard isBundle, let pathNow else { return false }
        return pathNow != running
    }

    static func isAppBundle(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path)
    }
}

/// Watches the launched bundle. Finder's Replace leaves this process running with a dead menu bar item.
@MainActor
final class BundleReplacementWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let bundleURL: URL
    private let runningID: BundleFileID
    private let relaunch: (URL) -> Void
    private var attempts = 0
    private var stopped = false
    // shortcut: waits about 2s for the new bundle, upgrade if Replace is still swapping after that
    private let maxAttempts = 10

    init?(bundleURL: URL = Bundle.main.bundleURL, relaunch: @escaping (URL) -> Void) {
        let fd = Darwin.open(bundleURL.path, O_EVTONLY)
        guard fd >= 0, let runningID = BundleFileID.of(descriptor: fd) else {
            if fd >= 0 { close(fd) }
            return nil
        }
        self.bundleURL = bundleURL
        self.runningID = runningID
        self.relaunch = relaunch
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.delete, .rename, .revoke],
            queue: .main
        )
        source.setCancelHandler {
            close(fd)
        }
        self.source = source
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.bundleMoved()
            }
        }
        source.resume()
    }

    func stop() {
        stopped = true
        source?.cancel()
        source = nil
    }

    private func bundleMoved() {
        guard !stopped else { return }
        source?.cancel()
        source = nil
        check()
    }

    private func check() {
        guard !stopped else { return }
        attempts += 1
        if BundleReplacement.shouldRelaunch(
            running: runningID,
            pathNow: BundleFileID.at(bundleURL),
            isBundle: BundleReplacement.isAppBundle(bundleURL)
        ) {
            stopped = true
            relaunch(bundleURL)
            return
        }
        guard attempts < maxAttempts else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            self.check()
        }
    }
}

@MainActor
enum AppRelaunch {
    /// Launch Services would otherwise activate this already-running (and now stale) instance.
    static func openReplacement(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, _ in
            guard app != nil else { return }
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }
}
