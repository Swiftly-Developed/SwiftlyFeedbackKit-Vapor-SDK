import Vapor

/// HTTP client for communicating with the FeedbackKit API.
/// Uses Vapor's `Client` for all requests.
public struct FeedbackKitClient: Sendable {
    let client: Client
    let configuration: FeedbackKitConfiguration
    let logger: Logger

    // MARK: - JSON Coding

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    // MARK: - SDK Operations (X-API-Key auth)

    func get<T: Content>(path: String, userId: String? = nil) async throws -> T {
        let uri = apiURI(path: path)
        let response = try await client.get(uri) { req in
            applyAPIKeyHeaders(to: &req.headers, userId: userId)
        }
        return try decodeOrThrow(response)
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
            logger.error("FeedbackKit decode error: \(error)")
            throw FeedbackKitError.decodingError(String(describing: error))
        }
    }

    private func errorForStatus(_ response: ClientResponse) -> FeedbackKitError {
        let message = try? response.content.decode(ErrorMessageDTO.self, using: Self.decoder).reason
        switch response.status.code {
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
        default: return .serverError(statusCode: UInt(response.status.code))
        }
    }
}

/// Internal DTO for decoding server error messages.
struct ErrorMessageDTO: Content {
    let error: Bool?
    let reason: String?
}
