import Vapor

/// Project management operations using Bearer token authentication.
public struct ProjectAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// List all projects the user has access to.
    public func list() async throws -> [ProjectListItem] {
        try await client.adminGet(path: "/projects", token: token)
    }

    /// Get a single project by ID.
    public func get(id: UUID) async throws -> ProjectResponse {
        try await client.adminGet(path: "/projects/\(id)", token: token)
    }

    /// Create a new project.
    public func create(_ request: CreateProjectRequest) async throws -> ProjectResponse {
        try await client.adminPost(path: "/projects", body: request, token: token)
    }

    /// Update a project.
    public func update(id: UUID, _ request: UpdateProjectRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(id)", body: request, token: token)
    }

    /// Delete a project (owner only).
    public func delete(id: UUID) async throws {
        try await client.adminDelete(path: "/projects/\(id)", token: token)
    }

    /// Archive a project (owner only).
    public func archive(id: UUID) async throws -> ProjectResponse {
        try await client.adminPostEmpty(path: "/projects/\(id)/archive", token: token)
    }

    /// Unarchive a project (owner only).
    public func unarchive(id: UUID) async throws -> ProjectResponse {
        try await client.adminPostEmpty(path: "/projects/\(id)/unarchive", token: token)
    }

    /// Regenerate the project API key (owner only).
    public func regenerateKey(id: UUID) async throws -> ProjectResponse {
        try await client.adminPostEmpty(path: "/projects/\(id)/regenerate-key", token: token)
    }

    /// Transfer project ownership.
    public func transferOwnership(id: UUID, _ request: TransferOwnershipRequest) async throws -> TransferOwnershipResponse {
        try await client.adminPost(path: "/projects/\(id)/transfer-ownership", body: request, token: token)
    }

    /// Update Slack settings.
    public func updateSlack(projectId: UUID, _ request: UpdateSlackSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/slack", body: request, token: token)
    }

    /// Update allowed statuses (Pro+ only).
    public func updateStatuses(projectId: UUID, _ request: UpdateAllowedStatusesRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/statuses", body: request, token: token)
    }

    /// Update email notification statuses.
    public func updateEmailNotifyStatuses(projectId: UUID, _ request: UpdateEmailNotifyStatusesRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/email-notify-statuses", body: request, token: token)
    }
}
