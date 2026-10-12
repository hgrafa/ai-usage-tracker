import Foundation

struct CredentialPrompt: Equatable, Sendable {
    var actionTitle: String
    var instructions: String
    var fieldLabel: String
    var showsSecretField: Bool

    static let claude = CredentialPrompt(
        actionTitle: "Set session cookie",
        instructions: "In claude.ai, open DevTools → Network, reload https://claude.ai/settings/usage, copy the usage request's Cookie header (or only the sessionKey value).",
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

    static func prompt(for provider: ProviderID) -> CredentialPrompt? {
        switch provider {
        case .claude: .claude
        case .cursor: .cursor
        case .grok: .grok
        case .codex: nil
        }
    }
}
