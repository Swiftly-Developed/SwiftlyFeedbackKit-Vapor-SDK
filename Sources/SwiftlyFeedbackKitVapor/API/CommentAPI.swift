import Vapor

/// Comment operations using X-API-Key authentication.
public struct CommentAPI: Sendable {
    let client: FeedbackKitClient

    /// List all comments for a feedback item.
    public func list(feedbackId: UUID) async throws -> [CommentResponse] {
        try await client.get(path: "/feedbacks/\(feedbackId)/comments")
    }

    /// Add a comment to a feedback item.
    public func create(feedbackId: UUID, request: CreateCommentRequest) async throws -> CommentResponse {
        try await client.post(path: "/feedbacks/\(feedbackId)/comments", body: request)
    }

    /// Delete a comment.
    public func delete(feedbackId: UUID, commentId: UUID) async throws {
        try await client.delete(path: "/feedbacks/\(feedbackId)/comments/\(commentId)")
    }
}
