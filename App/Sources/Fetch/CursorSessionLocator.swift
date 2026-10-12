import Foundation

struct CursorSessionLocator: Sendable {
    var homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    func accessToken() async -> String? {
        let home = homeDirectory
        let path = Self.databasePath(home: home)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let uri = Self.databaseURI(home: home)
        let output = await Task.detached {
            BlockingProcess.run(
                executable: URL(fileURLWithPath: "/usr/bin/sqlite3"),
                arguments: [uri, "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken';"],
                timeout: 5
            )
        }.value
        guard output.status == 0, !output.timedOut else { return nil }
        guard let text = String(data: output.stdout, encoding: .utf8) else { return nil }
        return Self.normalizeToken(text)
    }

    static func databasePath(home: String) -> String {
        (home as NSString).appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    static func databaseURI(home: String) -> String {
        var path = databasePath(home: home)
        path = path.replacingOccurrences(of: "%", with: "%25")
        path = path.replacingOccurrences(of: " ", with: "%20")
        path = path.replacingOccurrences(of: "?", with: "%3F")
        path = path.replacingOccurrences(of: "#", with: "%23")
        return "file:\(path)?mode=ro"
    }

    static func normalizeToken(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let wrappedInDoubleQuotes = value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2
        let wrappedInSingleQuotes = value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2
        if wrappedInDoubleQuotes || wrappedInSingleQuotes {
            value = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.isEmpty ? nil : value
    }
}

enum TokenShape {
    static func isJWT(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { character in
                character.isLetter || character.isNumber || character == "-" || character == "_" || character == "="
            }
        }
    }

    static func bearerToken(from paste: String) -> String? {
        let trimmed = paste.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if isJWT(trimmed) { return trimmed }
        if let extracted = jwtAfterWorkOSCookie(in: trimmed) { return extracted }
        return firstJWT(in: trimmed)
    }

    private static func jwtAfterWorkOSCookie(in text: String) -> String? {
        guard let range = text.range(of: "WorkosCursorSessionToken=", options: .caseInsensitive) else { return nil }
        var value = String(text[range.upperBound...])
        if let end = value.firstIndex(of: ";") {
            value = String(value[..<end])
        }
        value = value.removingPercentEncoding ?? value
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = value.range(of: "::") {
            let jwt = String(value[separator.upperBound...])
            if isJWT(jwt) { return jwt }
        }
        if isJWT(value) { return value }
        return firstJWT(in: value)
    }

    private static func firstJWT(in text: String) -> String? {
        let pattern = #"[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text)
        else { return nil }
        let candidate = String(text[matchRange])
        return isJWT(candidate) ? candidate : nil
    }
}

struct CursorAccessTokenProvider: Sendable {
    static let missingTokenMessage = "Sign in to Cursor or set the Cursor token."

    var locator: CursorSessionLocator
    var store: KeychainCredentialStore

    func bearerToken() async throws -> String {
        let local = await locator.accessToken()
        let saved: String?
        do {
            saved = try store.load(provider: .cursor)?.secret
        } catch {
            if local == nil {
                throw UsageFetchError.message("The saved Cursor session could not be read.")
            }
            saved = nil
        }
        if let token = Self.bearer(local: local, saved: saved) {
            return token
        }
        if saved != nil {
            throw UsageFetchError.message("Paste a Cursor access token.")
        }
        throw UsageFetchError.message(Self.missingTokenMessage)
    }

    func hasCredential() async -> Bool {
        if await locator.accessToken() != nil { return true }
        return store.contains(provider: .cursor)
    }

    static func bearer(local: String?, saved: String?) -> String? {
        if let local {
            let trimmed = local.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        guard let saved else { return nil }
        return TokenShape.bearerToken(from: saved)
    }
}
