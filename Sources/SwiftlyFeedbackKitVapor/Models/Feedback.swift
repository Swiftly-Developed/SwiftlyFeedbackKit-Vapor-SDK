import Vapor

// MARK: - Enums

public enum FeedbackStatus: String, Content, CaseIterable, Sendable {
    case pending
    case approved
    case inProgress = "in_progress"
    case testflight
    case completed
    case rejected

    public var canVote: Bool {
        self != .completed && self != .rejected
    }
}

public enum FeedbackCategory: String, Content, Sendable {
    case featureRequest = "feature_request"
    case bugReport = "bug_report"
    case improvement
    case other
}

// MARK: - Response

public struct FeedbackResponse: Content, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let status: FeedbackStatus
    public let category: FeedbackCategory
    public let userId: String
    public let userEmail: String?
    public let voteCount: Int
    public let hasVoted: Bool
    public let commentCount: Int
    public let totalMrr: Double?
    public let createdAt: Date?
    public let updatedAt: Date?
    // Merge
    public let mergedIntoId: UUID?
    public let mergedAt: Date?
    public let mergedFeedbackIds: [UUID]?
    // Integrations
    public let githubIssueUrl: String?
    public let githubIssueNumber: Int?
    public let clickupTaskUrl: String?
    public let clickupTaskId: String?
    public let notionPageUrl: String?
    public let notionPageId: String?
    public let mondayItemUrl: String?
    public let mondayItemId: String?
    public let linearIssueUrl: String?
    public let linearIssueId: String?
    public let trelloCardUrl: String?
    public let trelloCardId: String?
    public let airtableRecordUrl: String?
    public let airtableRecordId: String?
    public let asanaTaskUrl: String?
    public let asanaTaskId: String?
    public let basecampTodoUrl: String?
    public let basecampTodoId: String?
    public let basecampBucketId: String?
    // Other
    public let rejectionReason: String?
    public let isHiddenOverLimit: Bool
    public let roadmapVisible: Bool
    public let roadmapTargetDate: Date?
    public let roadmapNote: String?

    public var isMerged: Bool { mergedIntoId != nil }
}

// MARK: - Requests

public struct CreateFeedbackRequest: Content, Sendable {
    public let title: String
    public let description: String
    public let category: FeedbackCategory
    public let userId: String
    public let userEmail: String?
    public let subscribeToMailingList: Bool?
    public let mailingListEmailTypes: [String]?

    public init(
        title: String,
        description: String,
        category: FeedbackCategory,
        userId: String,
        userEmail: String? = nil,
        subscribeToMailingList: Bool? = nil,
        mailingListEmailTypes: [String]? = nil
    ) {
        self.title = title
        self.description = description
        self.category = category
        self.userId = userId
        self.userEmail = userEmail
        self.subscribeToMailingList = subscribeToMailingList
        self.mailingListEmailTypes = mailingListEmailTypes
    }
}

public struct UpdateFeedbackRequest: Content, Sendable {
    public let title: String?
    public let description: String?
    public let status: FeedbackStatus?
    public let category: FeedbackCategory?
    public let rejectionReason: String?
    public let roadmapVisible: Bool?
    public let roadmapTargetDate: Date?
    public let roadmapNote: String?

    public init(
        title: String? = nil,
        description: String? = nil,
        status: FeedbackStatus? = nil,
        category: FeedbackCategory? = nil,
        rejectionReason: String? = nil,
        roadmapVisible: Bool? = nil,
        roadmapTargetDate: Date? = nil,
        roadmapNote: String? = nil
    ) {
        self.title = title
        self.description = description
        self.status = status
        self.category = category
        self.rejectionReason = rejectionReason
        self.roadmapVisible = roadmapVisible
        self.roadmapTargetDate = roadmapTargetDate
        self.roadmapNote = roadmapNote
    }
}

// MARK: - Merge

public struct MergeFeedbackRequest: Content, Sendable {
    public let primaryFeedbackId: UUID
    public let secondaryFeedbackIds: [UUID]

    public init(primaryFeedbackId: UUID, secondaryFeedbackIds: [UUID]) {
        self.primaryFeedbackId = primaryFeedbackId
        self.secondaryFeedbackIds = secondaryFeedbackIds
    }
}

public struct MergeFeedbackResponse: Content, Sendable {
    public let primaryFeedback: FeedbackResponse
    public let mergedCount: Int
    public let totalVotes: Int
    public let totalComments: Int
}
