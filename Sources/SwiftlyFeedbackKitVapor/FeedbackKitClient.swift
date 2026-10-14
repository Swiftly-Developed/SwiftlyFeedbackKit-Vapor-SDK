import Vapor

/// HTTP client for communicating with the FeedbackKit API.
/// Uses Vapor's `Client` for all requests.
public struct FeedbackKitClient: Sendable {
    let client: Client
    let configuration: FeedbackKitConfiguration
    let logger: Logger

    // MARK: - JSON Coding

    /// A fresh decoder. `JSONDecoder` is a class; one shared instance is not
    /// safe for the concurrent requests a Vapor host issues.
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// A fresh encoder. Same reason as ``decoder``.
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    // MARK: - SDK Operations (X-API-Key auth)

    func get<T: Content>(path: String, userId: String? = nil) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.get(uri) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
        }
        return try decodeOrThrow(response)
    }

    /// `get(path:userId:)` with a percent-encoded query. An empty item list
    /// produces exactly the URI the query-less spelling produces.
    func get<T: Content>(path: String, queryItems: [URLQueryItem], userId: String? = nil) async throws -> T {
        let uri = apiURI(path: path, queryItems: queryItems)
        let response = try await client.get(uri) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
        }
        return try decodeOrThrow(response)
    }

    func getData(path: String, queryItems: [URLQueryItem] = [], userId: String? = nil) async throws -> Data {
        let response = try await client.get(apiURI(path: path, queryItems: queryItems)) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
        }
        try checkStatus(response)
        guard let body = response.body else { return Data() }
        return Data(body.readableBytesView)
    }

    func post<T: Content, B: Content>(path: String, body: B, userId: String? = nil) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.post(uri) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
            try req.content.encode(body, using: Self.encoder)
        }
        return try decodeOrThrow(response)
    }

    func patch<T: Content, B: Content>(path: String, body: B, userId: String? = nil) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.patch(uri) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
            try req.content.encode(body, using: Self.encoder)
        }
        return try decodeOrThrow(response)
    }

    func delete(path: String, userId: String? = nil) async throws {
        let uri = apiURI(path: path)
        let response = try await client.delete(uri) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
        }
        try checkStatus(response)
    }

    func deleteWithBody<T: Content, B: Content>(path: String, body: B, userId: String? = nil) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.delete(uri) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
            try req.content.encode(body, using: Self.encoder)
        }
        return try decodeOrThrow(response)
    }

    // MARK: - Admin Operations (Bearer token auth)

    func adminGet<T: Content>(path: String, token: String) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.get(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
        }
        return try decodeOrThrow(response)
    }

    /// `adminGet(path:token:)` with a percent-encoded query. An empty item list
    /// produces exactly the URI the query-less spelling produces.
    func adminGet<T: Content>(path: String, queryItems: [URLQueryItem], token: String) async throws -> T {
        let uri = apiURI(path: path, queryItems: queryItems)
        let response = try await client.get(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
        }
        return try decodeOrThrow(response)
    }

    func adminPost<T: Content, B: Content>(path: String, body: B, token: String) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.post(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
            try req.content.encode(body, using: Self.encoder)
        }
        return try decodeOrThrow(response)
    }

    func adminPostEmpty<T: Content>(path: String, token: String) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.post(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
        }
        return try decodeOrThrow(response)
    }

    func adminPostNoResponse(path: String, token: String) async throws {
        let uri = apiURI(path: path)
        let response = try await client.post(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
        }
        try checkStatus(response)
    }

    func adminPutNoResponse<B: Content>(path: String, body: B, token: String) async throws {
        let uri = apiURI(path: path)
        let response = try await client.put(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
            try req.content.encode(body, using: Self.encoder)
        }
        try checkStatus(response)
    }

    func adminPatch<T: Content, B: Content>(path: String, body: B, token: String) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.patch(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
            try req.content.encode(body, using: Self.encoder)
        }
        return try decodeOrThrow(response)
    }

    func adminDelete(path: String, token: String) async throws {
        let uri = apiURI(path: path)
        let response = try await client.delete(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
        }
        try checkStatus(response)
    }

    func adminDeleteWithBody<B: Content>(path: String, body: B, token: String) async throws {
        let uri = apiURI(path: path)
        let response = try await client.delete(uri) { req in
            applyBearerHeaders(to: &req.headers, token: token)
            try req.content.encode(body, using: Self.encoder)
        }
        try checkStatus(response)
    }

    // MARK: - Unauthenticated

    func publicPost<T: Content, B: Content>(path: String, body: B) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.post(uri) { req in
            req.headers.contentType = .json
            try req.content.encode(body, using: Self.encoder)
        }
        return try decodeOrThrow(response)
    }

    func publicGet<T: Content>(path: String) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.get(uri) { req in
            req.headers.contentType = .json
        }
        return try decodeOrThrow(response)
    }

    // MARK: - Private Helpers

    private func apiURI(path: String) -> URI {
        URI(string: configuration.apiBaseURL.absoluteString + path)
    }

    /// The query-carrying spelling. With no items it falls through to the
    /// query-less helper above, so it never emits a bare trailing `?` and the
    /// URI every existing operation sends is unchanged byte for byte.
    private func apiURI(path: String, queryItems: [URLQueryItem]) -> URI {
        guard let query = URLQueryEncoding.query(queryItems) else { return apiURI(path: path) }
        return URI(string: configuration.apiBaseURL.absoluteString + path + "?" + query)
    }

    private func applyAPIKeyHeaders(to headers: inout HTTPHeaders, userId: String?) {
        headers.add(name: .contentType, value: "application/json")
        headers.add(name: "X-API-Key", value: configuration.apiKey)
        if let userId {
            headers.add(name: "X-User-Id", value: userId)
        }
    }

    private func applyBearerHeaders(to headers: inout HTTPHeaders, token: String) {
        headers.add(name: .contentType, value: "application/json")
        headers.bearerAuthorization = BearerAuthorization(token: token)
    }

    private func checkStatus(_ response: ClientResponse) throws {
        guard (200...299).contains(response.status.code) else {
            throw errorForStatus(response)
        }
    }

    private func decodeOrThrow<T: Content>(_ response: ClientResponse) throws -> T {
        guard (200...299).contains(response.status.code) else {
            throw errorForStatus(response)
        }
        do {
            return try response.content.decode(T.self, using: Self.decoder)
        } catch {
            // The decode error's description can include response field values.
            // Log the type only; the thrown error still carries the detail for the host.
            logger.error("FeedbackKit failed to decode \(T.self)")
            throw FeedbackKitError.decodingError(String(describing: error))
        }
    }

    /// The server speaks two error bodies, and which one arrives is decided by
    /// the JSON *type* of `error`, never by the status — 402 and 403 both
    /// arrive in either shape.
    ///
    /// - Shape A (enveloped): `error` is an object carrying `code` / `message`
    ///   / `field`, alongside a `timestamp`. The metrics surface sends this.
    /// - Shape B (boolean): `error` is `true` and the prose is in `reason`.
    ///   Vapor's own `ErrorMiddleware` and every other surface send this.
    ///
    /// Attempt A, fall back to B, and branch on which succeeded. Before this,
    /// a shape-A body failed the shape-B decode outright — `try?` swallowed
    /// the type mismatch — so the code was invisible and the prose was lost.
    private func errorForStatus(_ response: ClientResponse) -> FeedbackKitError {
        if let envelope = try? response.content.decode(ErrorEnvelopeDTO.self, using: Self.decoder) {
            return errorForEnvelope(envelope.error, statusCode: response.status.code)
        }
        let message = try? response.content.decode(ErrorMessageDTO.self, using: Self.decoder).reason
        return errorForStatusCode(response.status.code, message: message)
    }

    /// Shape A. A recognised metrics code wins over the status; anything else
    /// falls through to the same status mapping shape B uses, with the
    /// envelope's `message` as the prose.
    private func errorForEnvelope(_ detail: ErrorEnvelopeDTO.Detail, statusCode: UInt) -> FeedbackKitError {
        switch detail.code.flatMap(MetricsErrorCode.init(rawValue:)) {
        case .customEventsRequirePro:
            return .tierUpgradeRequired(code: detail.code, message: detail.message)
        case .measureRequiresBearer:
            return .measureNotAvailable(measure: detail.field, message: detail.message)
        default:
            return errorForStatusCode(statusCode, message: detail.message)
        }
    }

    private func errorForStatusCode(_ statusCode: UInt, message: String?) -> FeedbackKitError {
        switch statusCode {
        case 400: return .badRequest(message: message)
        case 401:
            if message?.lowercased().contains("api key") == true {
                return .invalidApiKey
            }
            return .unauthorized
        case 402: return .paymentRequired(message: message)
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .conflict
        case 429: return .rateLimited(message: message)
        default: return .serverError(statusCode: statusCode)
        }
    }
}

/// Internal DTO for decoding server error messages (shape B, the boolean form).
struct ErrorMessageDTO: Content {
    let error: Bool?
    let reason: String?
}

/// Internal DTO for decoding the metrics surface's enveloped error body
/// (shape A). `error` is non-optional on purpose: that is what makes this
/// decode fail — and the shape-B fallback run — for a boolean `error`.
struct ErrorEnvelopeDTO: Content {
    struct Detail: Content {
        let code: String?
        let message: String?
        let field: String?
    }

    let error: Detail
    let timestamp: String?
}
