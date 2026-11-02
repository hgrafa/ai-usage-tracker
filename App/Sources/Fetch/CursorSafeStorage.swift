import CommonCrypto
import Foundation
import Security

enum CursorSafeStorage {
    static let prefix = "cursor-safe-storage:v1:"
    private static let service = "Cursor Safe Storage"
    private static let account = "Cursor Key"

    static func isSealed(_ value: String) -> Bool {
        value.hasPrefix(prefix)
    }

    /// Opens a `cursor-safe-storage:v1:` value. Plaintext tokens pass through.
    /// shortcut: v10 envelopes only, add v11 if a sealed token no longer starts with base64 "djEw".
    static func token(from stored: String, password: String) -> String? {
        let value = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSealed(value) else { return value.isEmpty ? nil : value }
        guard let blob = Data(base64Encoded: String(value.dropFirst(prefix.count))),
              blob.starts(with: Data("v10".utf8)),
              blob.count > 3
        else { return nil }
        return decryptV10(blob.dropFirst(3), password: password)
    }

    private static let passwords = SafeStoragePasswords(
        readLogin: { prompt in loginPassword(prompt: prompt) },
        readSaved: { savedPassword() },
        writeSaved: { savePassword($0) }
    )

    /// The next password read may show one login-keychain dialog. Automatic refreshes do not call this.
    static func allowPrompt() async {
        await passwords.allowPrompt()
    }

    static func open(_ stored: String) async -> String? {
        guard let password = await passwords.password() else { return nil }
        return token(from: stored, password: password)
    }

    /// Always Allow does not stick for an ad-hoc signature, so the login item is copied into our keychain after one read.
    private static func loginPassword(prompt: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if !prompt {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        }
        return copyPassword(query)
    }

    private static func savedPassword() -> String? {
        var query = savedQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return copyPassword(query)
    }

    private static func savePassword(_ password: String) {
        let query = savedQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var add = query
            for (key, value) in attributes {
                add[key] = value
            }
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private static func savedQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainCredentialStore.service,
            kSecAttrAccount as String: "cursor-safe-storage",
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
        ]
    }

    private static func copyPassword(_ query: [String: Any]) -> String? {
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        let password = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .init(charactersIn: "\u{0}"))
        return password?.isEmpty == false ? password : nil
    }

    private static func decryptV10(_ ciphertext: Data.SubSequence, password: String) -> String? {
        let passwordBytes = Array(password.utf8)
        let salt = Array("saltysalt".utf8)
        var key = [UInt8](repeating: 0, count: 16)
        let derived = passwordBytes.withUnsafeBufferPointer { passwordBuffer in
            salt.withUnsafeBufferPointer { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.baseAddress.map { UnsafePointer<Int8>(OpaquePointer($0)) },
                    passwordBytes.count,
                    saltBuffer.baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                    1003,
                    &key,
                    key.count
                )
            }
        }
        guard derived == kCCSuccess else { return nil }

        let cipher = Data(ciphertext)
        var output = [UInt8](repeating: 0, count: cipher.count + kCCBlockSizeAES128)
        var moved = 0
        let iv = [UInt8](repeating: 0x20, count: kCCBlockSizeAES128)
        let decrypted = cipher.withUnsafeBytes { cipherBytes in
            CCCrypt(
                CCOperation(kCCDecrypt),
                CCAlgorithm(kCCAlgorithmAES),
                CCOptions(kCCOptionPKCS7Padding),
                key,
                key.count,
                iv,
                cipherBytes.baseAddress,
                cipher.count,
                &output,
                output.count,
                &moved
            )
        }
        guard decrypted == kCCSuccess, moved > 0 else { return nil }
        let text = String(bytes: output.prefix(moved), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }
}

/// Reads Cursor's login-keychain password at most once. Later reads use memory, then our own keychain item.
actor SafeStoragePasswords {
    private var memory: String?
    private var armed = false
    private var inflight: Task<String?, Never>?
    private let readLogin: @Sendable (Bool) -> String?
    private let readSaved: @Sendable () -> String?
    private let writeSaved: @Sendable (String) -> Void

    init(
        readLogin: @escaping @Sendable (Bool) -> String?,
        readSaved: @escaping @Sendable () -> String?,
        writeSaved: @escaping @Sendable (String) -> Void
    ) {
        self.readLogin = readLogin
        self.readSaved = readSaved
        self.writeSaved = writeSaved
    }

    func allowPrompt() {
        armed = true
    }

    func password() async -> String? {
        if let saved = readSaved(), !saved.isEmpty {
            memory = saved
            return saved
        }
        if let memory { return memory }
        if let inflight { return await inflight.value }
        let prompt = armed
        armed = false
        let readLogin = self.readLogin
        let job = Task { () -> String? in
            // Background refresh must not touch the login item. A skipped lookup can still raise its dialog.
            guard prompt else { return nil }
            return readLogin(true)
        }
        inflight = job
        let value = await job.value
        inflight = nil
        if let value {
            memory = value
            writeSaved(value)
        }
        return value
    }
}
