import Vapor

/// Admin-level feedback operations using Bearer token authentication.
public struct AdminFeedbackAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// Update a feedback item (status, title, description, category, rejection reason, roadmap fields).
    public func update(id: UUID, _ request: UpdateFeedbackRequest) async throws -> FeedbackResponse {
        try await client.adminPatch(path: "/feedbacks/\(id)", body: request, token: token)
    }

    /// Delete a feedback item (owner/admin only).
    public func delete(id: UUID) async throws {
        try await client.adminDelete(path: "/feedbacks/\(id)", token: token)
    }

    /// Merge feedback items into a primary item.
    public func merge(_ request: MergeFeedbackRequest) async throws -> MergeFeedbackResponse {
        try await client.adminPost(path: "/feedbacks/merge", body: request, token: token)
    }
}
