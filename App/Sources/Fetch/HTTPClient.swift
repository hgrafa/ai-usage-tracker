import Foundation

protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

struct HTTPResponse: Equatable, Sendable {
    var statusCode: Int
    var body: Data
}

struct URLSessionHTTPClient: HTTPClient {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw UsageFetchError.network
            }
            return HTTPResponse(statusCode: http.statusCode, body: data)
        } catch let error as UsageFetchError {
            throw error
        } catch is CancellationError {
            throw UsageFetchError.network
        } catch {
            throw UsageFetchError.transport(error, url: request.url)
        }
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration, delegate: RedirectGuard(), delegateQueue: nil)
    }()
}

/// Drops redirects that would carry Cookie or Authorization to another host.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let originalHost = task.originalRequest?.url?.host,
              request.url?.host == originalHost
        else { return nil }
        return request
    }
}
