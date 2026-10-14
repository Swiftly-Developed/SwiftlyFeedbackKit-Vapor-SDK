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

    /// Metrics reads on this (X-API-Key) surface. The Bearer twin is
    /// `FeedbackKitAdmin.metrics`, which reaches the revenue and audience
    /// measures this one refuses.
    public var metrics: MetricsAPI { MetricsAPI(client: client) }
}
