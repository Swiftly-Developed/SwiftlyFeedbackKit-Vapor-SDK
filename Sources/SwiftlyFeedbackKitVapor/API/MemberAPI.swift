import Vapor

/// Project member management using Bearer token authentication.
public struct MemberAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    // MARK: - Members

    /// List all members of a project.
    public func list(projectId: UUID) async throws -> [ProjectMemberPublic] {
        try await client.adminGet(path: "/projects/\(projectId)/members", token: token)
    }

    /// Add a member to a project by email.
    public func add(projectId: UUID, _ request: AddMemberRequest) async throws -> AddMemberResponse {
        try await client.adminPost(path: "/projects/\(projectId)/members", body: request, token: token)
    }

    /// Update a member's role.
    public func updateRole(projectId: UUID, memberId: UUID, _ request: UpdateMemberRoleRequest) async throws -> ProjectMemberPublic {
        try await client.adminPatch(path: "/projects/\(projectId)/members/\(memberId)", body: request, token: token)
    }

    /// Remove a member from a project.
    public func remove(projectId: UUID, memberId: UUID) async throws {
        try await client.adminDelete(path: "/projects/\(projectId)/members/\(memberId)", token: token)
    }

    // MARK: - Invites

    /// List pending invites for a project.
    public func listInvites(projectId: UUID) async throws -> [ProjectInviteResponse] {
        try await client.adminGet(path: "/projects/\(projectId)/invites", token: token)
    }

    /// Cancel a pending invite.
    public func cancelInvite(projectId: UUID, inviteId: UUID) async throws {
        try await client.adminDelete(path: "/projects/\(projectId)/invites/\(inviteId)", token: token)
    }

    /// Resend an invite email.
    public func resendInvite(projectId: UUID, inviteId: UUID) async throws {
        try await client.adminPostNoResponse(path: "/projects/\(projectId)/invites/\(inviteId)/resend", token: token)
    }

    /// Accept an invite.
    public func acceptInvite(_ request: AcceptInviteRequest) async throws -> AcceptInviteResponse {
        try await client.adminPost(path: "/projects/invites/accept", body: request, token: token)
    }

    /// Preview an invite (no auth required).
    public func previewInvite(code: String) async throws -> InvitePreviewResponse {
        try await client.publicGet(path: "/projects/invites/preview/\(code)")
    }
}
