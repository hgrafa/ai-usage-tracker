import AppKit
import UserNotifications

enum NotificationPermission: Equatable, Sendable {
    case notAsked
    case allowed
    case denied
}

final class LimitNotifier: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        case .notDetermined: .notAsked
        @unknown default: .notAsked
        }
    }

    func requestPermission() async -> NotificationPermission {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted ? .allowed : await permission()
    }

    func post(_ alert: LimitAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: alert.identifier, content: content, trigger: nil))
    }

    /// The popover activates the app, and macOS hides banners for the frontmost app unless asked.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    @MainActor
    static func openSystemSettings() {
        var link = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        if let bundleID = Bundle.main.bundleIdentifier {
            link += "?id=\(bundleID)"
        }
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }
}
