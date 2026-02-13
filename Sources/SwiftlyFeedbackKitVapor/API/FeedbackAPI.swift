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
        return try await client.get(path: "/feedbacks\(queryString)", userId: userId)
    }

    /// Get a single feedback item by ID.
    public func get(id: UUID, userId: String? = nil) async throws -> FeedbackResponse {
        try await client.get(path: "/feedbacks/\(id)", userId: userId)
    }

    /// Submit new feedback.
    public func create(_ request: CreateFeedbackRequest) async throws -> FeedbackResponse {
        try await client.post(path: "/feedbacks", body: request, userId: request.userId)
    }

    /// Delete a feedback item (requires the feedback creator's userId or admin).
    public func delete(id: UUID) async throws {
        try await client.delete(path: "/feedbacks/\(id)")
    }
}
