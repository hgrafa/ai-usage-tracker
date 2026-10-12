import Foundation

enum CredentialKind: String, Codable, Equatable, Sendable {
    case sessionCookie
    case apiKey
    case localSession
}

struct Credential: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    var provider: ProviderID
    var kind: CredentialKind
    var secret: String

    var description: String {
        "Credential(provider: \(provider.rawValue), kind: \(kind.rawValue))"
    }

    var debugDescription: String { description }
}
