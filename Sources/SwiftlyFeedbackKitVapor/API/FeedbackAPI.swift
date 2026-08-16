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
    public func list(
        status: FeedbackStatus? = nil,
        category: FeedbackCategory? = nil,
        includeMerged: Bool? = nil,
        userId: String? = nil
    ) async throws -> [FeedbackResponse] {
        var query: [String] = []
        if let status { query.append("status=\(status.rawValue)") }
        if let category { query.append("category=\(category.rawValue)") }
        if let includeMerged { query.append("includeMerged=\(includeMerged)") }
        let queryString = query.isEmpty ? "" : "?\(query.joined(separator: "&"))"
        // Tolerant element-drop decode (AGENTS.md contract): one row with an
        // unknown `status`/`category` token must not poison the whole list.
        let elements: [TolerantElement<FeedbackResponse>] =
            try await client.get(path: "/feedbacks\(queryString)", userId: userId)
        return elements.compactMap(\.value)
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
