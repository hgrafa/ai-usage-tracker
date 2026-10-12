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
        let hosting = PopoverHostingController(rootView: UsagePopover(model: model))
        hosting.sizingOptions = .preferredContentSize
        hosting.safeAreaRegions = []
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

    func popoverDidShow(_ notification: Notification) {
        popover.contentViewController?.view.window?.animationBehavior = .none
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    private func applyTitle() {
        let image = MenuBarTitle.statusImage(for: model.menuBarReadings)
        statusItem.length = max(image.size.width, 28)
        guard let button = statusItem.button else { return }
        button.image = image
        button.imageScaling = .scaleNone
        button.imagePosition = .imageOnly
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        let label = model.menuBarReadings.map(MenuBarLabel.itemLabel).joined(separator: ", ")
        button.setAccessibilityLabel(label.isEmpty ? "AI Usage" : label)
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

private final class PopoverHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidLayout() {
        super.viewDidLayout()
        view.window?.animationBehavior = .none
    }
}
