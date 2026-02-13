import Vapor

// MARK: - Request

public struct CreateCommentRequest: Content, Sendable {
    public let content: String
    public let userId: String
    public let isAdmin: Bool?

    public init(content: String, userId: String, isAdmin: Bool? = nil) {
        self.content = content
        self.userId = userId
        self.isAdmin = isAdmin
    }
}

// MARK: - Response

public struct CommentResponse: Content, Sendable {
    public let id: UUID
    public let content: String
    public let userId: String
    public let isAdmin: Bool
    public let createdAt: Date?
}
