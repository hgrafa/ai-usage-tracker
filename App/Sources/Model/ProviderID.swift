import Foundation

enum ProviderID: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case claude
    case codex
    case cursor
    case grok

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .grok: "Grok Bot"
        }
    }
}
