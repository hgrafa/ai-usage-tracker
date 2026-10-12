import Foundation

struct FetcherRegistry: Sendable {
    var claude: ClaudeUsageFetcher
    var codex: CodexUsageFetcher
    var cursor: CursorUsageFetcher
    var grok: GrokUsageFetcher

    init(store: KeychainCredentialStore, locator: CursorSessionLocator = CursorSessionLocator(), http: URLSessionHTTPClient = URLSessionHTTPClient()) {
        let tokens = CursorAccessTokenProvider(locator: locator, store: store)
        claude = ClaudeUsageFetcher(store: store, http: http)
        codex = CodexUsageFetcher()
        cursor = CursorUsageFetcher(tokens: tokens, http: http)
        grok = GrokUsageFetcher(tokens: tokens, http: http)
    }

    func fetch(_ provider: ProviderID) async -> Result<UsageSnapshot, UsageFetchError> {
        do {
            let snapshot: UsageSnapshot
            switch provider {
            case .claude: snapshot = try await claude.fetch()
            case .codex: snapshot = try await codex.fetch()
            case .cursor: snapshot = try await cursor.fetch()
            case .grok: snapshot = try await grok.fetch()
            }
            return .success(snapshot)
        } catch let error as UsageFetchError {
            return .failure(error)
        } catch {
            return .failure(.network)
        }
    }
}
