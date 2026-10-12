import Foundation

struct KeychainCredentialStore: CredentialStoring, Sendable {
    static let service = "dev.hgrafa.ai-usage-widget"

    func load(provider: ProviderID) throws -> Credential? {
        var query = baseQuery(account: provider.rawValue)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialStoreError.unavailable
        }
        do {
            return try JSONDecoder().decode(Credential.self, from: data)
        } catch {
            throw CredentialStoreError.unreadable
        }
    }

    func save(_ credential: Credential) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(credential)
        } catch {
            throw CredentialStoreError.unreadable
        }
        let query = baseQuery(account: credential.provider.rawValue)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrLabel as String: "AI Usage \(credential.provider.displayName)"
        ]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            var add = query
            for (key, value) in attributes {
                add[key] = value
            }
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else { throw CredentialStoreError.unavailable }
            return
        }
        guard update == errSecSuccess else { throw CredentialStoreError.unavailable }
    }

    func delete(provider: ProviderID) throws {
        let status = SecItemDelete(baseQuery(account: provider.rawValue) as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        throw CredentialStoreError.unavailable
    }

    func contains(provider: ProviderID) -> Bool {
        let query = baseQuery(account: provider.rawValue)
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
