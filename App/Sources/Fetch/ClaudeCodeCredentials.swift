import Foundation

enum ClaudeTokenRead: Equatable, Sendable {
    case fresh(String)
    case expired
    case missing
}

/// Reads the login Claude Code saved. Read-only: the widget never refreshes this token,
/// because a refresh rotates it and would sign Claude Code out.
struct ClaudeCodeCredentials: Sendable {
    static let keychainService = "Claude Code-credentials"
    /// A token this close to expiry could lapse mid-request.
    static let expiryMargin: TimeInterval = 60

    var homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    var keychain: @Sendable () -> Data? = { ClaudeCodeCredentials.keychainItem() }

    func token(now: Date) -> ClaudeTokenRead {
        if let data = keychain() {
            let read = Self.read(data, now: now)
            if read != .missing { return read }
        }
        let file = URL(fileURLWithPath: homeDirectory).appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: file) else { return .missing }
        return Self.read(data, now: now)
    }

    static func read(_ data: Data, now: Date) -> ClaudeTokenRead {
        guard let object = JSONFields.decodeObject(data),
              let oauth = JSONFields.dictionary(object["claudeAiOauth"]),
              let token = JSONFields.string(oauth["accessToken"])
        else { return .missing }
        if let scopes = oauth["scopes"] as? [String], !scopes.contains("user:profile") {
            return .missing
        }
        if let expiresAt = JSONFields.date(from: oauth["expiresAt"], milliseconds: true),
           expiresAt <= now.addingTimeInterval(expiryMargin) {
            return .expired
        }
        return .fresh(token)
    }

    /// Claude Code writes this item with /usr/bin/security, so reading it the same way does not prompt.
    static func keychainItem() -> Data? {
        let output = BlockingProcess.run(
            executable: URL(fileURLWithPath: "/usr/bin/security"),
            arguments: ["find-generic-password", "-s", keychainService, "-w"],
            timeout: 5
        )
        guard output.status == 0, !output.timedOut, !output.stdout.isEmpty else { return nil }
        return output.stdout
    }
}

enum ClaudeOAuthUsage {
    static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func request(token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("AI-Usage", forHTTPHeaderField: "User-Agent")
        return request
    }
}
