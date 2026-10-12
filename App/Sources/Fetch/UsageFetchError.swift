import Foundation

enum UsageFetchError: Error, Equatable, LocalizedError, Sendable {
    case unauthorized(ProviderID)
    case rateLimited
    case network
    case malformed
    case message(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .unauthorized(let provider):
            switch provider {
            case .cursor, .grok:
                return "Cursor rejected the session. Sign in again, or paste a new token."
            case .claude:
                return "Claude rejected the session cookie."
            case .codex:
                return "The request was not authorized."
            }
        case .rateLimited:
            return "Too many requests. Try again in a little while."
        case .network:
            return "The usage request failed."
        case .malformed:
            return "The usage response could not be read."
        case .message(let text):
            return text
        case .notConfigured:
            return "Not configured."
        }
    }

    /// Maps a transport failure without copying the URL or the system error text.
    static func transport(_ error: Error, url: URL?) -> UsageFetchError {
        _ = (error, url)
        return .network
    }
}

enum HTTPFailureMapper {
    static func map(
        statusCode: Int,
        body: Data,
        provider: ProviderID,
        htmlMeansUnauthorized: Bool
    ) -> UsageFetchError? {
        if (200..<300).contains(statusCode) {
            if htmlMeansUnauthorized, looksLikeHTML(body) {
                return .unauthorized(provider)
            }
            return nil
        }
        switch statusCode {
        case 401, 403:
            return .unauthorized(provider)
        case 429:
            return .rateLimited
        default:
            return .network
        }
    }

    static func looksLikeHTML(_ body: Data) -> Bool {
        let prefix = body.prefix(256)
        guard let text = String(data: prefix, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else { return false }
        return text.hasPrefix("<!doctype html")
            || text.hasPrefix("<html")
            || text.hasPrefix("<head")
            || text.contains("<html")
    }
}
