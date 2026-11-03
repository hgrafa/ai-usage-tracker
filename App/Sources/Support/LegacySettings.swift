import Foundation

/// The app used to ship as `dev.hgrafa.ai-usage-widget`. Carry the user's own choices over once,
/// but none of the system state (menu bar visibility, Sparkle bookkeeping) that came with that identity.
enum LegacySettings {
    static let bundleIdentifier = "dev.hgrafa.ai-usage-widget"
    static let migratedKey = "migratedLegacySettings"

    private static let keys = [
        AppModel.enabledSectionsKey,
        AppModel.alertThresholdsKey,
        AppModel.announcedAlertsKey,
        AppModel.showsProviderStatusKey
    ]

    static func migrate(
        from old: UserDefaults? = UserDefaults(suiteName: bundleIdentifier),
        to new: UserDefaults = .standard
    ) {
        guard !new.bool(forKey: migratedKey) else { return }
        new.set(true, forKey: migratedKey)
        guard let old else { return }
        for key in keys where new.object(forKey: key) == nil {
            if let value = old.object(forKey: key) {
                new.set(value, forKey: key)
            }
        }
    }
}
