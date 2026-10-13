import SwiftUI

@main
struct AIUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var inserted = false

    var body: some Scene {
        // The visible item is the status bar controller. This scene only keeps the app alive.
        MenuBarExtra(isInserted: $inserted) {
            EmptyView()
        } label: {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppModel.isRunningUnderTest else { return }
        statusBar = StatusBarController(model: AppModel(), updater: AppUpdater())
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.reveal()
        return false
    }
}
