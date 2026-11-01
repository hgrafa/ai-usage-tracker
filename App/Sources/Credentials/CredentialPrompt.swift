import Foundation

struct CredentialPrompt: Equatable, Sendable {
    var actionTitle: String
    var instructions: String
    var fieldLabel: String
    var showsSecretField: Bool

    static let claude = CredentialPrompt(
        actionTitle: "Set session cookie",
        instructions: "Run claude auth login in Terminal and AI Usage reads your Claude Code login. No Claude Code? In claude.ai, open DevTools → Network, reload https://claude.ai/settings/usage, and paste the Cookie header, sessionKey=…, or just the token.",
        fieldLabel: "claude.ai session cookie",
        showsSecretField: true
    )

    static let cursor = CredentialPrompt(
        actionTitle: "Save access token",
        instructions: "Sign in to the Cursor app, or paste a Cursor access token.",
        fieldLabel: "Access token",
        showsSecretField: true
    )

    static let grok = CredentialPrompt(
        actionTitle: "",
        instructions: "Sign in to Cursor or set the Cursor token.",
        fieldLabel: "",
        showsSecretField: false
    )

    static let openrouter = CredentialPrompt(
        actionTitle: "Save API key",
        instructions: "Paste an API key from https://openrouter.ai/settings/keys. A normal key shows that key's spend cap and free-model quota.",
        fieldLabel: "API key",
        showsSecretField: true
    )

    static let deepseek = CredentialPrompt(
        actionTitle: "Save API key",
        instructions: "Paste an API key from https://platform.deepseek.com/api_keys. DeepSeek reports the remaining balance, not a percent cap.",
        fieldLabel: "API key",
        showsSecretField: true
    )

    static let moonshot = CredentialPrompt(
        actionTitle: "Save API key",
        instructions: "Paste an API key from https://platform.kimi.ai or https://platform.moonshot.cn. Moonshot reports the remaining balance, not a percent cap.",
        fieldLabel: "API key",
        showsSecretField: true
    )

    static let anthropic = CredentialPrompt(
        actionTitle: "Save key or cookie",
        instructions: "Organizations: paste an Admin API key (sk-ant-admin…) to see this month's spend. Individual accounts: in platform.claude.com, open DevTools → Network, reload, and paste a request's Cookie header to see the credit left.",
        fieldLabel: "Admin API key or Console cookie",
        showsSecretField: true
    )

    static func prompt(for provider: ProviderID) -> CredentialPrompt? {
        switch provider {
        case .claude: .claude
        case .cursor: .cursor
        case .grok: .grok
        case .openrouter: .openrouter
        case .deepseek: .deepseek
        case .moonshot: .moonshot
        case .anthropic: .anthropic
        case .codex: nil
        }
    }
}
