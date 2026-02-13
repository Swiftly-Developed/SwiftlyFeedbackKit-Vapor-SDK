import Vapor

public struct FeedbackByStatus: Content, Sendable {
    public let pending: Int
    public let approved: Int
    public let inProgress: Int
    public let testflight: Int
    public let completed: Int
    public let rejected: Int
}

public struct FeedbackByCategory: Content, Sendable {
    public let featureRequest: Int
    public let bugReport: Int
    public let improvement: Int
    public let other: Int
}

public struct ProjectStats: Content, Sendable {
    public let id: UUID
    public let name: String
    public let isArchived: Bool
    public let colorIndex: Int
    public let feedbackCount: Int
    public let feedbackByStatus: FeedbackByStatus
    public let feedbackByCategory: FeedbackByCategory
    public let userCount: Int
    public let commentCount: Int
    public let voteCount: Int
}

public struct HomeDashboard: Content, Sendable {
    public let totalProjects: Int
    public let totalFeedback: Int
    public let feedbackByStatus: FeedbackByStatus
    public let feedbackByCategory: FeedbackByCategory
    public let totalUsers: Int
    public let totalComments: Int
    public let totalVotes: Int
    public let projectStats: [ProjectStats]
}
