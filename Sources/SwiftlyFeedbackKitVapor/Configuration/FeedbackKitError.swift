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
    /// 402 - A metrics request the caller's subscription tier cannot answer,
    /// carrying the enveloped body's machine-readable `code`
    /// (`METRICS_CUSTOM_EVENTS_REQUIRE_PRO`).
    ///
    /// Distinct from ``paymentRequired(message:)``, which stays the case for
    /// the boolean-shaped 402 every other surface sends.
    case tierUpgradeRequired(code: String?, message: String?)
    /// 403 - Insufficient permissions or archived project.
    case forbidden
    /// 403 - A metrics measure the caller's *authentication surface* cannot
    /// serve (`METRICS_MEASURE_REQUIRES_BEARER`) — a surface refusal, not a
    /// role denial and not a billing one, so it is deliberately not named
    /// after revenue.
    ///
    /// `measure` carries the envelope's `field`, which names the request field
    /// the refusal is about. ``forbidden`` remains the case for the
    /// boolean-shaped 403 — the role denial and the suspended project — so the
    /// two 403s stay distinguishable.
    case measureNotAvailable(measure: String?, message: String?)
    /// 404 - Resource not found.
    case notFound
    /// 409 - Conflict (e.g. duplicate vote).
    case conflict
    /// 429 - The caller exceeded the surface's request budget.
    case rateLimited(message: String?)
    /// 5xx - Server error.
    case serverError(statusCode: UInt)
    /// Failed to decode the API response.
    case decodingError(String)
    /// The SDK has not been configured.
    case notConfigured
    /// The operation cannot be performed by this SDK's auth surface — thrown
    /// before any request is issued (e.g. a deprecated operation whose route
    /// the server registers behind a different credential).
    case operationNotSupported(String)
}

extension FeedbackKitError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .badRequest: .badRequest
        case .unauthorized, .invalidApiKey: .unauthorized
        case .paymentRequired: .paymentRequired
        case .tierUpgradeRequired: .paymentRequired
        case .forbidden: .forbidden
        case .measureNotAvailable: .forbidden
        case .notFound: .notFound
        case .conflict: .conflict
        case .rateLimited: .tooManyRequests
        case .serverError(let code): HTTPResponseStatus(statusCode: Int(code))
        case .decodingError: .internalServerError
        case .notConfigured: .internalServerError
        case .operationNotSupported: .internalServerError
        }
    }

    public var reason: String {
        switch self {
        case .badRequest(let msg): msg ?? "Bad request"
        case .unauthorized: "Unauthorized"
        case .invalidApiKey: "Invalid API key"
        case .paymentRequired(let msg): msg ?? "Payment required"
        case .tierUpgradeRequired(let code, let msg): msg ?? code ?? "Upgrade required"
        case .forbidden: "Forbidden"
        case .measureNotAvailable(let measure, let msg):
            msg ?? "Measure not available on this authentication surface\(measure.map { " (\($0))" } ?? "")"
        case .notFound: "Not found"
        case .conflict: "Conflict"
        case .rateLimited(let msg): msg ?? "Too many requests"
        case .serverError(let code): "Server error (\(code))"
        case .decodingError(let msg): "Decoding error: \(msg)"
        case .notConfigured: "FeedbackKit has not been configured. Call app.feedbackKit.configure() first."
        case .operationNotSupported(let msg): msg
        }
    }
}
