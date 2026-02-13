import Vapor

/// Voting operations using X-API-Key authentication.
public struct VoteAPI: Sendable {
    let client: FeedbackKitClient

    /// Add a vote for a feedback item.
    public func vote(feedbackId: UUID, request: CreateVoteRequest) async throws -> VoteResponse {
        try await client.post(path: "/feedbacks/\(feedbackId)/votes", body: request, userId: request.userId)
    }

    /// Remove a vote from a feedback item.
    public func unvote(feedbackId: UUID, request: CreateVoteRequest) async throws -> VoteResponse {
        try await client.deleteWithBody(path: "/feedbacks/\(feedbackId)/votes", body: request, userId: request.userId)
    }
}
