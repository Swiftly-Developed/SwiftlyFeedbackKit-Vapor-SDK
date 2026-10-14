import Vapor

/// Feedback CRUD operations using X-API-Key authentication.
public struct FeedbackAPI: Sendable {
    let client: FeedbackKitClient

    /// List all feedback for the project.
    /// - Parameters:
    ///   - status: Filter by status.
    ///   - category: Filter by category.
    ///   - includeMerged: Include merged feedback items.
    ///   - userId: The SDK user ID (enables `hasVoted` and hidden-over-limit filtering).
    ///   - page: 1-indexed page. Omit to read every page.
    ///   - perPage: Page size. The server clamps this to 1...100.
    public func list(
        status: FeedbackStatus? = nil,
        category: FeedbackCategory? = nil,
        includeMerged: Bool? = nil,
        userId: String? = nil,
        page: Int? = nil,
        perPage: Int? = nil
    ) async throws -> [FeedbackResponse] {
        // Order is pinned: status, category, includeMerged, then `paged`,
        // `page`, `per_page`. `URLQueryItem` preserves insertion order, and
        // the key `includeMerged` is camelCase on the wire. `paged=1` is
        // always sent so a current server returns the envelope. `page` is
        // appended only when the caller set it, or when a later page is read.
        var query: [URLQueryItem] = []
        if let status { query.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let category { query.append(URLQueryItem(name: "category", value: category.rawValue)) }
        if let includeMerged { query.append(URLQueryItem(name: "includeMerged", value: "\(includeMerged)")) }
        return try await SDKListPage.collect(page: page, perPage: perPage) { extra in
            try await client.getData(path: "/feedbacks", queryItems: query + extra, userId: userId)
        } decode: { data in
            try SDKListPage.decoding { try Self.decodePage(data) }
        }
    }

    /// Tolerant element-drop decode: one row with an unknown `status` or
    /// `category` token must not poison the whole page.
    private static func decodePage(_ data: Data) throws -> SDKListPage.Decoded<FeedbackResponse> {
        let json = try JSONSerialization.jsonObject(with: data)
        let decoder = FeedbackKitClient.decoder
        if json is [Any] {
            let elements = try decoder.decode([TolerantElement<FeedbackResponse>].self, from: data)
            return .legacy(elements.compactMap(\.value))
        }
        let envelope = try decoder.decode(
            SDKListPage.Envelope<TolerantElement<FeedbackResponse>>.self,
            from: data
        )
        return .page(items: envelope.items.compactMap(\.value), meta: envelope.meta)
    }

    /// Get a single feedback item by ID.
    public func get(id: UUID, userId: String? = nil) async throws -> FeedbackResponse {
        try await client.get(path: "/feedbacks/\(id)", userId: userId)
    }

    /// Submit new feedback.
    public func create(_ request: CreateFeedbackRequest) async throws -> FeedbackResponse {
        try await client.post(path: "/feedbacks", body: request, userId: request.userId)
    }

    /// Delete a feedback item.
    ///
    /// - Warning: This operation has **never worked**: the server registers
    ///   `DELETE /feedbacks/:id` behind Bearer authentication only, so the
    ///   X-API-Key credential this surface sends was rejected on every call.
    ///   Deletion is an admin action — use `FeedbackKitAdmin`'s
    ///   `feedback.delete(id:)` instead. Since the fix for F3 (fix record
    ///   `2026-08-15`) this method throws
    ///   `FeedbackKitError.operationNotSupported` immediately instead of
    ///   issuing the doomed request and returning a misleading 401.
    @available(*, deprecated, message: "This operation has never worked: DELETE /feedbacks/:id is a Bearer-only route, so the X-API-Key call always failed. Deletion is an admin action - use FeedbackKitAdmin's feedback.delete(id:).")
    public func delete(id: UUID) async throws {
        throw FeedbackKitError.operationNotSupported(
            "FeedbackAPI.delete(id:) has never worked: the server registers DELETE /feedbacks/:id behind Bearer authentication only. Deletion is an admin action - use FeedbackKitAdmin's feedback.delete(id:)."
        )
    }
}
