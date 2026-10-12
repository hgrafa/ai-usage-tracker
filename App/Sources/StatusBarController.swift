import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var observation: AnyCancellable?

    init(model: AppModel) {
        self.model = model
        super.init()
        let hosting = NSHostingController(rootView: UsagePopover(model: model))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.appearance = NSAppearance(named: .darkAqua)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        observation = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.applyTitle()
            }
        }
        applyTitle()
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    private func applyTitle() {
        let title = MenuBarTitle.attributedTitle(for: model.menuBarReadings)
        statusItem.length = MenuBarTitle.statusLength(for: title)
        statusItem.button?.attributedTitle = title
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        sender.highlight(true)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
