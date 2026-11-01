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

    static func open(_ stored: String) -> String? {
        guard let password = keychainPassword() else { return nil }
        return token(from: stored, password: password)
    }

    private static func keychainPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
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
