import Foundation

enum APIKeyRequests {
    static func token(for provider: ProviderID, store: KeychainCredentialStore) throws -> String {
        let secret: String
        do {
            secret = try store.load(provider: provider)?.secret ?? ""
        } catch {
            throw UsageFetchError.message("The API key could not be read.")
        }
        var value = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("bearer ") {
            value = String(value.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !value.isEmpty else { throw UsageFetchError.notConfigured }
        return value
    }

    static func get(_ url: URL, token: String, provider: ProviderID, http: URLSessionHTTPClient) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let response = try await http.send(request)
        if let failure = HTTPFailureMapper.map(
            statusCode: response.statusCode,
            body: response.body,
            provider: provider,
            htmlMeansUnauthorized: false
        ) {
            throw failure
        }
        return response.body
    }
}
