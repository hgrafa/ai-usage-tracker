import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var observation: AnyCancellable?
    private var outsideClickMonitor: Any?

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
        installOutsideClickMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
        removeOutsideClickMonitor()
    }

    /// `.transient` never sees a click on another menu bar item (Weather, Control Center).
    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.popover.isShown else { return }
                self.popover.performClose(nil)
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func applyTitle() {
        let image = MenuBarTitle.statusImage(for: model.menuBarReadings)
        statusItem.length = max(image.size.width, 28)
        guard let button = statusItem.button else { return }
        image.isTemplate = true
        button.image = image
        button.image?.isTemplate = true
        button.imageScaling = .scaleNone
        button.imagePosition = .imageOnly
        button.title = ""
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
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.window?.animationBehavior = .none
        guard let root = view.window?.contentView?.superview ?? view.window?.contentView else { return }
        keepPopoverGlassActive(root)
    }

    /// Default popover glass follows key state and turns flat grey when this screen is not focused.
    private func keepPopoverGlassActive(_ view: NSView) {
        if let effect = view as? NSVisualEffectView {
            if effect.blendingMode != .behindWindow { effect.blendingMode = .behindWindow }
            if effect.state != .active { effect.state = .active }
        }
        view.subviews.forEach(keepPopoverGlassActive)
    }
}
