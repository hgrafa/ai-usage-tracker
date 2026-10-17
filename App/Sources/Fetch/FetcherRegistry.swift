import Foundation

struct FetcherRegistry: Sendable {
    var claude: ClaudeUsageFetcher
    var codex: CodexUsageFetcher
    var cursor: CursorUsageFetcher
    var grok: GrokUsageFetcher
    var openrouter: OpenRouterUsageFetcher
    var deepseek: DeepSeekUsageFetcher
    var moonshot: MoonshotUsageFetcher
    var anthropic: AnthropicAPIUsageFetcher

    init(store: KeychainCredentialStore, locator: CursorSessionLocator = CursorSessionLocator(), http: URLSessionHTTPClient = URLSessionHTTPClient()) {
        let tokens = CursorAccessTokenProvider(locator: locator, store: store)
        claude = ClaudeUsageFetcher(store: store, http: http)
        codex = CodexUsageFetcher()
        cursor = CursorUsageFetcher(tokens: tokens, http: http)
        grok = GrokUsageFetcher(tokens: tokens, http: http)
        openrouter = OpenRouterUsageFetcher(store: store, http: http)
        deepseek = DeepSeekUsageFetcher(store: store, http: http)
        moonshot = MoonshotUsageFetcher(store: store, http: http)
        anthropic = AnthropicAPIUsageFetcher(store: store, http: http)
    }

    func fetch(_ provider: ProviderID) async -> Result<UsageSnapshot, UsageFetchError> {
        do {
            let snapshot: UsageSnapshot
            switch provider {
            case .claude: snapshot = try await claude.fetch()
            case .codex: snapshot = try await codex.fetch()
            case .cursor: snapshot = try await cursor.fetch()
            case .grok: snapshot = try await grok.fetch()
            case .openrouter: snapshot = try await openrouter.fetch()
            case .deepseek: snapshot = try await deepseek.fetch()
            case .moonshot: snapshot = try await moonshot.fetch()
            case .anthropic: snapshot = try await anthropic.fetch()
            }
            return .success(snapshot)
        } catch let error as UsageFetchError {
            return .failure(error)
        } catch {
            return .failure(.network)
        }
    }
}
