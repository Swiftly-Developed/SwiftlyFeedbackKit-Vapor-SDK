import Vapor

/// Event tracking using X-API-Key authentication.
public struct EventAPI: Sendable {
    let client: FeedbackKitClient

    /// Track a view or custom event.
    public func track(_ request: TrackViewEventRequest) async throws -> ViewEventResponse {
        try await client.post(path: "/events/track", body: request)
    }
}
