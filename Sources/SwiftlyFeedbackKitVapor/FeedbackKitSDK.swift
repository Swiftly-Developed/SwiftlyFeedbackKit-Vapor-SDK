import Vapor

/// SDK-level operations using X-API-Key authentication.
/// Use this for feedback submission, voting, commenting, user registration, and event tracking.
public struct FeedbackKitSDK: Sendable {
    let client: FeedbackKitClient

    /// Feedback CRUD operations.
    public var feedback: FeedbackAPI { FeedbackAPI(client: client) }

    /// Voting operations.
    public var votes: VoteAPI { VoteAPI(client: client) }

    /// Comment operations.
    public var comments: CommentAPI { CommentAPI(client: client) }

    /// SDK user registration and tracking.
    public var users: SDKUserAPI { SDKUserAPI(client: client) }

    /// Event tracking.
    public var events: EventAPI { EventAPI(client: client) }
}
