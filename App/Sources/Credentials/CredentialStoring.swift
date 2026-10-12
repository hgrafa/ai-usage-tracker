import Foundation

protocol CredentialStoring: Sendable {
    func load(provider: ProviderID) throws -> Credential?
    func save(_ credential: Credential) throws
    func delete(provider: ProviderID) throws
    func contains(provider: ProviderID) -> Bool
}

enum CredentialStoreError: Error, Equatable {
    case unreadable
    case unavailable
}
