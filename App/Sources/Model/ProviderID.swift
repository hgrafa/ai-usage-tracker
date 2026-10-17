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

/// The menu bar and the popover follow this order. A missing list keeps the built-in order.
/// Providers added after a list was saved are appended, so an old save does not hide them.
struct ProviderOrder: Equatable, Sendable {
    var providers: [ProviderID]

    static let standard = ProviderOrder(providers: Array(ProviderID.allCases))

    init(providers: [ProviderID]) {
        self.providers = providers
    }

    init(stored raw: [String]?) {
        guard let raw else {
            self = .standard
            return
        }
        var seen = Set<ProviderID>()
        var ordered: [ProviderID] = []
        for name in raw {
            guard let provider = ProviderID(rawValue: name), seen.insert(provider).inserted else { continue }
            ordered.append(provider)
        }
        for provider in ProviderID.allCases where seen.insert(provider).inserted {
            ordered.append(provider)
        }
        providers = ordered
    }

    var stored: [String] {
        providers.map(\.rawValue)
    }

    func moving(from source: IndexSet, to destination: Int) -> ProviderOrder {
        var next = providers
        next.move(fromOffsets: source, toOffset: destination)
        return ProviderOrder(providers: next)
    }

    func visible(_ enabled: Set<ProviderID>) -> [ProviderID] {
        providers.filter { enabled.contains($0) }
    }
}
