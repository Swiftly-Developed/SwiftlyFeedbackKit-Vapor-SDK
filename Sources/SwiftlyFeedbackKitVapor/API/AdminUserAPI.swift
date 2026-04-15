import Vapor

/// Admin-level SDK user listing and stats using Bearer token authentication.
public struct AdminUserAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// List SDK users for a project.
    public func list(projectId: UUID) async throws -> [SDKUserListResponse] {
        try await client.adminGet(path: "/users/project/\(projectId)", token: token)
    }

    /// Get user stats for a project.
    public func stats(projectId: UUID) async throws -> SDKUsersStats {
        try await client.adminGet(path: "/users/project/\(projectId)/stats", token: token)
    }

    /// List SDK users across all accessible projects.
    public func listAll() async throws -> [SDKUserListResponse] {
        try await client.adminGet(path: "/users/all", token: token)
    }

    /// Get user stats across all accessible projects.
    public func allStats() async throws -> SDKUsersStats {
        try await client.adminGet(path: "/users/all/stats", token: token)
    }
}
