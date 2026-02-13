import Vapor

/// Admin-level event stats using Bearer token authentication.
public struct AdminEventAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// List recent events for a project (limit 100).
    public func list(projectId: UUID) async throws -> [ViewEventResponse] {
        try await client.adminGet(path: "/events/project/\(projectId)", token: token)
    }

    /// Get event stats for a project.
    public func stats(projectId: UUID, days: Int? = nil) async throws -> ViewEventsOverview {
        let query = days.map { "?days=\($0)" } ?? ""
        return try await client.adminGet(path: "/events/project/\(projectId)/stats\(query)", token: token)
    }

    /// Get event stats across all projects.
    public func allStats(days: Int? = nil) async throws -> ViewEventsOverview {
        let query = days.map { "?days=\($0)" } ?? ""
        return try await client.adminGet(path: "/events/all/stats\(query)", token: token)
    }
}
