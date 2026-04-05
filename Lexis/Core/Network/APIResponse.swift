import Foundation

// MARK: - Response Envelope

struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let meta: APIMeta?
    let error: APIError?
}

struct APIMeta: Decodable {
    let timestamp: String?
    let requestId: String?
    let cursor: String?
    let hasMore: Bool?
    let limit: Int?
}

struct APIError: Decodable, LocalizedError {
    let code: String
    let message: String
    let details: [String: String]?

    var errorDescription: String? { message }
}

// MARK: - App-Level Errors

enum LexisError: LocalizedError {
    case apiError(APIError)
    case noData
    case unauthorized
    /// HTTP 403 — caller may treat as “no access” (e.g. guest) without clearing session.
    case forbidden
    /// HTTP 5xx or service unavailable.
    case serverUnavailable
    /// Other non-success HTTP codes (after 401/403 handled in client).
    case httpStatus(Int)
    case networkUnavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .apiError(let e): return e.message
        case .noData: return "Unexpected server response. Please try again."
        case .unauthorized: return "Session expired. Please sign in again."
        case .forbidden:
            return "This action isn’t available with your current session. Sign in for full access."
        case .serverUnavailable:
            return "The server is temporarily unavailable. Please try again."
        case .httpStatus(let code):
            return "Request failed (\(code)). Please try again."
        case .networkUnavailable: return "No internet connection."
        case .unknown(let e): return e.localizedDescription
        }
    }
}
