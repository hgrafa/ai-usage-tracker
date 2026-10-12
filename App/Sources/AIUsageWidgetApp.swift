import SwiftUI

@main
struct AIUsageWidgetApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(model: model)
        } label: {
            MenuBarLabel(percent: model.menuBarPercent)
        }
        .menuBarExtraStyle(.window)
    }
}
