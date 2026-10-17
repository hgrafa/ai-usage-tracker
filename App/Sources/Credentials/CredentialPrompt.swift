import Foundation

struct CredentialPrompt: Equatable, Sendable {
    var actionTitle: String
    var instructions: String
    var fieldLabel: String
    var showsSecretField: Bool

    static let claude = CredentialPrompt(
        actionTitle: "Set session cookie",
        instructions: "In claude.ai, open DevTools → Network, reload https://claude.ai/settings/usage, and paste the Cookie header, sessionKey=…, or just the token.",
        fieldLabel: "Session cookie",
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

    static func prompt(for provider: ProviderID) -> CredentialPrompt? {
        switch provider {
        case .claude: .claude
        case .cursor: .cursor
        case .grok: .grok
        case .openrouter: .openrouter
        case .deepseek: .deepseek
        case .moonshot: .moonshot
        case .codex: nil
        }
    }
}
