import Foundation

enum ProviderID: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case claude
    case codex
    case cursor
    case grok
    case openrouter
    case deepseek
    case moonshot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .grok: "Grok Bot"
        case .openrouter: "OpenRouter"
        case .deepseek: "DeepSeek"
        case .moonshot: "Moonshot"
        }
    }
}

struct EnabledSections: Equatable, Sendable {
    var providers: Set<ProviderID>

    static let all = EnabledSections(providers: Set(ProviderID.allCases))

    init(providers: Set<ProviderID>) {
        self.providers = providers
    }

    /// Missing storage means every section is on. An empty array means the user turned them all off.
    init(stored raw: [String]?) {
        guard let raw else {
            self = .all
            return
        }
        providers = Set(raw.compactMap(ProviderID.init(rawValue:)))
    }

    var stored: [String] {
        providers.map(\.rawValue).sorted()
    }

    func contains(_ provider: ProviderID) -> Bool {
        providers.contains(provider)
    }
}
