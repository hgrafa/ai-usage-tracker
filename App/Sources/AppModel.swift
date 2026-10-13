import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var phases: [ProviderID: ProviderPhase]
    @Published private(set) var savedSecretProviders: Set<ProviderID> = []
    @Published private(set) var enabledProviders: Set<ProviderID>
    @Published private(set) var serviceHealth: [ProviderID: ServiceHealth] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var alertThresholds: Set<Int>
    @Published private(set) var notificationPermission: NotificationPermission = .notAsked

    static let autoRefreshInterval: TimeInterval = 10 * 60
    static let staleInterval: TimeInterval = 60
    static let enabledSectionsKey = "enabledProviders"
    static let alertThresholdsKey = "limitAlertThresholds"
    static let announcedAlertsKey = "limitAlertsAnnounced"

    var menuBarReadings: [MenuBarReading] {
        MenuBarMath.readings(in: phases, visible: visibleProviders)
    }

    var latestFetchedAt: Date? {
        MenuBarMath.snapshots(from: visiblePhases).map(\.fetchedAt).max()
    }

    var visibleProviders: [ProviderID] {
        ProviderID.allCases.filter { enabledProviders.contains($0) }
    }

    private var visiblePhases: [ProviderID: ProviderPhase] {
        phases.filter { enabledProviders.contains($0.key) }
    }

    private let store: KeychainCredentialStore
    private let tokens: CursorAccessTokenProvider
    private let registry: FetcherRegistry
    private let defaults: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private var refreshAgain = false
    private var autoRefreshTask: Task<Void, Never>?
    private var alertTracker: LimitAlertTracker
    private let notifier: LimitNotifier?

    init(
        store: KeychainCredentialStore = KeychainCredentialStore(),
        locator: CursorSessionLocator = CursorSessionLocator(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.tokens = CursorAccessTokenProvider(locator: locator, store: store)
        self.registry = FetcherRegistry(store: store, locator: locator)
        self.defaults = defaults
        enabledProviders = EnabledSections(stored: defaults.stringArray(forKey: Self.enabledSectionsKey)).providers
        alertThresholds = AlertThresholds(stored: defaults.array(forKey: Self.alertThresholdsKey) as? [Int]).values
        alertTracker = LimitAlertTracker(announced: defaults.dictionary(forKey: Self.announcedAlertsKey) as? [String: Int] ?? [:])
        if Self.isRunningUnderTest {
            notifier = nil
            phases = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { ($0, ProviderPhase.unconfigured) })
        } else {
            notifier = LimitNotifier()
            phases = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { ($0, ProviderPhase.loading(stale: nil)) })
            startAutoRefresh()
            refresh()
            refreshNotificationPermission()
        }
    }

    func refresh() {
        if refreshTask != nil {
            refreshAgain = true
            return
        }
        refreshTask = Task { @MainActor in
            await self.runRefreshLoop()
        }
    }

    func refreshIfStale(maxAge: TimeInterval = AppModel.staleInterval) {
        if isRefreshing { return }
        if let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < maxAge { return }
        refresh()
    }

    func saveSecret(for provider: ProviderID, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard provider == .claude || provider == .cursor else { return }
        let kind: CredentialKind = (provider == .claude || trimmed.contains("WorkosCursorSessionToken")) ? .sessionCookie : .apiKey
        do {
            try store.save(Credential(provider: provider, kind: kind, secret: trimmed))
        } catch {
            let stale = MenuBarMath.snapshot(for: provider, in: phases)
            phases[provider] = .failed(message: "The credential could not be saved.", stale: stale)
            return
        }
        refresh()
    }

    func isSectionEnabled(_ provider: ProviderID) -> Bool {
        enabledProviders.contains(provider)
    }

    func setSectionEnabled(_ provider: ProviderID, enabled: Bool) {
        var next = enabledProviders
        if enabled {
            next.insert(provider)
        } else {
            next.remove(provider)
        }
        guard next != enabledProviders else { return }
        enabledProviders = next
        defaults.set(EnabledSections(providers: next).stored, forKey: Self.enabledSectionsKey)
        if enabled {
            refresh()
        }
    }

    func isAlertThresholdEnabled(_ threshold: Int) -> Bool {
        alertThresholds.contains(threshold)
    }

    func setAlertThreshold(_ threshold: Int, enabled: Bool) {
        var next = alertThresholds
        if enabled {
            next.insert(threshold)
        } else {
            next.remove(threshold)
        }
        let thresholds = AlertThresholds(stored: Array(next))
        guard thresholds.values != alertThresholds else { return }
        alertThresholds = thresholds.values
        defaults.set(thresholds.stored, forKey: Self.alertThresholdsKey)
        guard enabled, let notifier else { return }
        Task { @MainActor in
            if self.notificationPermission == .notAsked {
                self.notificationPermission = await notifier.requestPermission()
            }
            for snapshot in MenuBarMath.snapshots(from: self.visiblePhases) {
                self.announceCrossings(in: snapshot)
            }
        }
    }

    func refreshNotificationPermission() {
        guard let notifier else { return }
        Task { @MainActor in
            self.notificationPermission = await notifier.permission()
        }
    }

    func removeSecret(for provider: ProviderID) {
        do {
            try store.delete(provider: provider)
        } catch {
            let stale = MenuBarMath.snapshot(for: provider, in: phases)
            phases[provider] = .failed(message: "The credential could not be removed.", stale: stale)
            return
        }
        refresh()
    }

    private func startAutoRefresh() {
        autoRefreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.autoRefreshInterval))
                if Task.isCancelled { break }
                self.refresh()
            }
        }
    }

    private func runRefreshLoop() async {
        isRefreshing = true
        defer { isRefreshing = false }
        repeat {
            refreshAgain = false
            await performRefresh()
        } while refreshAgain && !Task.isCancelled
        refreshTask = nil
    }

    private func performRefresh() async {
        savedSecretProviders = []
        if store.contains(provider: .claude) { savedSecretProviders.insert(.claude) }
        if store.contains(provider: .cursor) { savedSecretProviders.insert(.cursor) }

        var configured: [ProviderID] = []
        if savedSecretProviders.contains(.claude) { configured.append(.claude) }
        configured.append(.codex)
        if await tokens.hasCredential() {
            configured.append(.cursor)
            configured.append(.grok)
        }
        configured = configured.filter { enabledProviders.contains($0) }

        var stale: [ProviderID: UsageSnapshot] = [:]
        for provider in ProviderID.allCases where enabledProviders.contains(provider) {
            if configured.contains(provider) {
                if let previous = MenuBarMath.snapshot(for: provider, in: phases) {
                    stale[provider] = previous
                }
                phases[provider] = .loading(stale: stale[provider])
            } else {
                phases[provider] = .unconfigured
            }
        }

        async let healthFetch = StatusPageFetcher().fetch()
        let registry = self.registry
        await withTaskGroup(of: (ProviderID, Result<UsageSnapshot, UsageFetchError>).self) { group in
            for provider in configured {
                group.addTask {
                    await Self.fetchProvider(provider, registry: registry)
                }
            }
            for await (provider, result) in group {
                apply(provider, result: result, stale: stale[provider])
            }
        }
        mergeHealth(await healthFetch)
        lastRefreshAt = Date()
    }

    private func mergeHealth(_ fetched: [ProviderID: ServiceHealth]) {
        for (provider, health) in fetched {
            if health.level == .unknown, let existing = serviceHealth[provider], existing.level != .unknown {
                continue
            }
            serviceHealth[provider] = health
        }
    }

    private nonisolated static func fetchProvider(
        _ provider: ProviderID,
        registry: FetcherRegistry
    ) async -> (ProviderID, Result<UsageSnapshot, UsageFetchError>) {
        let result = await registry.fetch(provider)
        return (provider, result)
    }

    private func apply(_ provider: ProviderID, result: Result<UsageSnapshot, UsageFetchError>, stale: UsageSnapshot?) {
        switch result {
        case .success(let snapshot):
            phases[provider] = .loaded(snapshot)
            announceCrossings(in: snapshot)
        case .failure(let error):
            let message = oneLine(error.errorDescription ?? "The usage request failed.")
            phases[provider] = .failed(message: message, stale: stale)
        }
    }

    private func announceCrossings(in snapshot: UsageSnapshot) {
        let alerts = alertTracker.alerts(for: snapshot, thresholds: alertThresholds)
        defaults.set(alertTracker.announced, forKey: Self.announcedAlertsKey)
        for alert in alerts {
            notifier?.post(alert)
        }
    }

    private func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
    }

    static var isRunningUnderTest: Bool {
        if NSClassFromString("XCTestCase") != nil { return true }
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["XCInjectBundleInto"] != nil
    }
}
