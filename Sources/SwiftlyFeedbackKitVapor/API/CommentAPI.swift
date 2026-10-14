import Vapor

/// Comment operations using X-API-Key authentication.
public struct CommentAPI: Sendable {
    let client: FeedbackKitClient

    /// List all comments for a feedback item.
    ///
    /// - Parameter userId: When set, sent as `X-User-Id`. The server shows
    ///   comments on feedback hidden over the Free-tier cap only when that
    ///   header matches the item's creator. The body is not consulted for that check.
    public func list(
        feedbackId: UUID,
        userId: String? = nil,
        page: Int? = nil,
        perPage: Int? = nil
    ) async throws -> [CommentResponse] {
        try await SDKListPage.collect(page: page, perPage: perPage) { extra in
            try await client.getData(
                path: "/feedbacks/\(feedbackId)/comments",
                queryItems: extra,
                userId: userId
            )
        } decode: { data in
            try SDKListPage.decoding {
                let json = try JSONSerialization.jsonObject(with: data)
                let decoder = FeedbackKitClient.decoder
                if json is [Any] {
                    return .legacy(try decoder.decode([CommentResponse].self, from: data))
                }
                let envelope = try decoder.decode(SDKListPage.Envelope<CommentResponse>.self, from: data)
                return .page(items: envelope.items, meta: envelope.meta)
            }
        }
    }

    /// Add a comment to a feedback item.
    ///
    /// Sends `request.userId` as `X-User-Id` as well as in the body. The hidden
    /// over-limit guard reads only the header, and a header that disagrees with
    /// the body is rejected.
    public func create(feedbackId: UUID, request: CreateCommentRequest) async throws -> CommentResponse {
        try await client.post(
            path: "/feedbacks/\(feedbackId)/comments",
            body: request,
            userId: request.userId
        )
    }

    /// Delete a comment.
    ///
    /// Pass `userId` to delete that SDK user's own non-admin comment. The
    /// request carries `X-API-Key` and `X-User-Id`. Pass `bearerToken` to
    /// delete any comment as a project owner or admin. That request carries
    /// `Authorization: Bearer` and no API key. A token wins when both are set.
    /// Calling with neither throws before a request is sent: the historical
    /// key-only call cannot prove who is deleting.
    public func delete(
        feedbackId: UUID,
        commentId: UUID,
        userId: String? = nil,
        bearerToken: String? = nil
    ) async throws {
        let path = "/feedbacks/\(feedbackId)/comments/\(commentId)"
        if let bearerToken, !bearerToken.isEmpty {
            try await client.adminDelete(path: path, token: bearerToken)
            return
        }
        guard let userId, !userId.isEmpty else {
            throw FeedbackKitError.operationNotSupported(
                "CommentAPI.delete requires userId (the SDK user's own non-admin comment) or bearerToken (a project owner or admin)."
            )
        }
        try await client.delete(path: path, userId: userId)
    }
}
