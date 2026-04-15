import Vapor

/// Errors returned by the FeedbackKit API.
public enum FeedbackKitError: Error, Sendable {
    /// 400 - Validation or request error.
    case badRequest(message: String?)
    /// 401 - Missing or invalid authentication.
    case unauthorized
    /// 401 - Invalid API key.
    case invalidApiKey
    /// 402 - Subscription tier limit exceeded.
    case paymentRequired(message: String?)
    /// 403 - Insufficient permissions or archived project.
    case forbidden
    /// 404 - Resource not found.
    case notFound
    /// 409 - Conflict (e.g. duplicate vote).
    case conflict
    /// 5xx - Server error.
    case serverError(statusCode: UInt)
    /// Failed to decode the API response.
    case decodingError(String)
    /// The SDK has not been configured.
    case notConfigured
}

extension FeedbackKitError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .badRequest: .badRequest
        case .unauthorized, .invalidApiKey: .unauthorized
        case .paymentRequired: .paymentRequired
        case .forbidden: .forbidden
        case .notFound: .notFound
        case .conflict: .conflict
        case .serverError(let code): HTTPResponseStatus(statusCode: Int(code))
        case .decodingError: .internalServerError
        case .notConfigured: .internalServerError
        }
    }

    public var reason: String {
        switch self {
        case .badRequest(let msg): msg ?? "Bad request"
        case .unauthorized: "Unauthorized"
        case .invalidApiKey: "Invalid API key"
        case .paymentRequired(let msg): msg ?? "Payment required"
        case .forbidden: "Forbidden"
        case .notFound: "Not found"
        case .conflict: "Conflict"
        case .serverError(let code): "Server error (\(code))"
        case .decodingError(let msg): "Decoding error: \(msg)"
        case .notConfigured: "FeedbackKit has not been configured. Call app.feedbackKit.configure() first."
        }
    }
}
