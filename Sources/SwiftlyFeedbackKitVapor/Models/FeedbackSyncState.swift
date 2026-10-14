import Vapor

/// One provider's outbox state for a feedback item.
///
/// Wire object inside `sync_states` on a feedback response
/// (`FeedbackSyncStateDTO`). `providerRefUrl` is the spelling
/// `.convertFromSnakeCase` binds for `provider_ref_url`.
public struct FeedbackSyncState: Content, Sendable {
    public let provider: String
    public let state: String
    public let providerRefUrl: String?
}
