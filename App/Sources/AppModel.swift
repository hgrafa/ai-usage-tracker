import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var phases: [ProviderID: ProviderPhase]
    @Published private(set) var savedSecretProviders: Set<ProviderID> = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshAt: Date?

    static let autoRefreshInterval: TimeInterval = 10 * 60
    static let staleInterval: TimeInterval = 60

    var menuBarPercent: Int? {
        MenuBarMath.percent(from: phases)
    }

    var latestFetchedAt: Date? {
        MenuBarMath.snapshots(from: phases).map(\.fetchedAt).max()
    }

    private let store: KeychainCredentialStore
    private let tokens: CursorAccessTokenProvider
    private let registry: FetcherRegistry
    private var refreshTask: Task<Void, Never>?
    private var refreshAgain = false
    private var autoRefreshTask: Task<Void, Never>?

    init(store: KeychainCredentialStore = KeychainCredentialStore(), locator: CursorSessionLocator = CursorSessionLocator()) {
        self.store = store
        self.tokens = CursorAccessTokenProvider(locator: locator, store: store)
        self.registry = FetcherRegistry(store: store, locator: locator)
        if Self.isRunningUnderTest {
            phases = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { ($0, ProviderPhase.unconfigured) })
        } else {
            phases = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { ($0, ProviderPhase.loading(stale: nil)) })
            startAutoRefresh()
            refresh()
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

        var stale: [ProviderID: UsageSnapshot] = [:]
        for provider in ProviderID.allCases {
            if configured.contains(provider) {
                if let previous = MenuBarMath.snapshot(for: provider, in: phases) {
                    stale[provider] = previous
                }
                phases[provider] = .loading(stale: stale[provider])
            } else {
                phases[provider] = .unconfigured
            }
        }

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
        lastRefreshAt = Date()
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
        case .failure(let error):
            let message = oneLine(error.errorDescription ?? "The usage request failed.")
            phases[provider] = .failed(message: message, stale: stale)
        }
    }

    private func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
    }

    private static var isRunningUnderTest: Bool {
        if NSClassFromString("XCTestCase") != nil { return true }
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["XCInjectBundleInto"] != nil
    }
}
