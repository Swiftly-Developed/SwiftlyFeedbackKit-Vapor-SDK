import Vapor

// MARK: - Request

public struct RegisterSDKUserRequest: Content, Sendable {
    public let userId: String
    public let mrr: Double?

    public init(userId: String, mrr: Double? = nil) {
        self.userId = userId
        self.mrr = mrr
    }
}

// MARK: - Responses

public struct SDKUserResponse: Content, Sendable {
    public let id: UUID
    public let userId: String
    public let mrr: Double?
    public let firstSeenAt: Date?
    public let lastSeenAt: Date?
}

public struct SDKUserListResponse: Content, Sendable {
    public let id: UUID
    public let userId: String
    public let mrr: Double?
    public let feedbackCount: Int
    public let voteCount: Int
    public let firstSeenAt: Date?
    public let lastSeenAt: Date?
}

public struct SDKUsersStats: Content, Sendable {
    public let totalUsers: Int
    /// Named `totalMrr` (not `totalMRR`) deliberately: the server sends
    /// `total_mrr`, and the client's `.convertFromSnakeCase` strategy resolves
    /// that to `totalMrr` — an uppercase acronym run can never bind
    /// (fix record `2026-08-15`, F1).
    public let totalMrr: Double
    public let usersWithMrr: Int
    public let averageMrr: Double
}
