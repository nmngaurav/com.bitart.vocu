import Foundation

// MARK: - API Client

final class APIClient: Sendable {
    static let shared = APIClient()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        anonymousTokenOverride: String? = nil
    ) async throws -> T {
        let req = try buildRequest(endpoint, anonymousTokenOverride: anonymousTokenOverride)
        let start = Date()
        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw LexisError.unknown(URLError(.badServerResponse))
        }

        #if DEBUG
        LexisLogger.networkResponse(request: req, http: http, data: data, start: start)
        #endif

        if http.statusCode == 401 {
            throw LexisError.unauthorized
        }

        // Do not JSON-decode error bodies (e.g. 403 with empty body) — avoids bogus decode errors.
        guard (200...299).contains(http.statusCode) else {
            switch http.statusCode {
            case 403:
                throw LexisError.forbidden
            case 404:
                throw LexisError.httpStatus(404)
            case 408, 504:
                throw LexisError.networkUnavailable
            default:
                if http.statusCode >= 500 {
                    throw LexisError.serverUnavailable
                }
                throw LexisError.httpStatus(http.statusCode)
            }
        }

        guard !data.isEmpty else {
            throw LexisError.noData
        }

        let decoded: APIResponse<T>
        do {
            decoded = try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            #if DEBUG
            LexisLogger.networkDecodeFailure(url: req.url, data: data, error: error)
            #endif
            throw error
        }

        if let error = decoded.error {
            throw LexisError.apiError(error)
        }
        guard let result = decoded.data else {
            throw LexisError.noData
        }
        return result
    }

    // MARK: - Void Request (204 or ignored body)

    func requestVoid(_ endpoint: Endpoint) async throws {
        let req = try buildRequest(endpoint)
        let start = Date()
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { return }
        #if DEBUG
        LexisLogger.networkResponse(request: req, http: http, data: data, start: start)
        #endif
        if http.statusCode == 401 { throw LexisError.unauthorized }
        if http.statusCode == 403 { throw LexisError.forbidden }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode >= 500 { throw LexisError.serverUnavailable }
            throw LexisError.httpStatus(http.statusCode)
        }
    }

    // MARK: - Build URLRequest

    private func buildRequest(_ endpoint: Endpoint, anonymousTokenOverride: String? = nil) throws -> URLRequest {
        guard let url = URL(string: endpoint.urlString) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Auth header
        if let override = anonymousTokenOverride {
            req.setValue("Bearer \(override)", forHTTPHeaderField: "Authorization")
        } else if endpoint.requiresAuth, let token = TokenStore.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        req.httpBody = endpoint.body
        return req
    }

    // MARK: - Token Refresh

    func refreshAccessToken() async throws -> String {
        guard let refreshToken = TokenStore.shared.refreshToken else {
            throw LexisError.unauthorized
        }
        let response: RefreshResponse = try await request(.refreshToken(refreshToken: refreshToken))
        TokenStore.shared.accessToken = response.accessToken
        return response.accessToken
    }
}
