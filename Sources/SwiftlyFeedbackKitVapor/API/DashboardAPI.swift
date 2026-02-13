import Vapor

/// Dashboard analytics using Bearer token authentication.
public struct DashboardAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// Get aggregated stats across all user projects.
    public func home() async throws -> HomeDashboard {
        try await client.adminGet(path: "/dashboard/home", token: token)
    }

    /// Get stats for a specific project.
    public func project(id: UUID) async throws -> ProjectStats {
        try await client.adminGet(path: "/dashboard/project/\(id)", token: token)
    }
}
