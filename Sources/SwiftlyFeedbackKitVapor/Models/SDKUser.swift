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
    public let totalMRR: Double
    public let usersWithMRR: Int
    public let averageMRR: Double
}
