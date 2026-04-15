import Vapor

// MARK: - Request

public struct CreateVoteRequest: Content, Sendable {
    public let userId: String
    public let email: String?
    public let notifyStatusChange: Bool?
    public let subscribeToMailingList: Bool?
    public let mailingListEmailTypes: [String]?

    public init(
        userId: String,
        email: String? = nil,
        notifyStatusChange: Bool? = nil,
        subscribeToMailingList: Bool? = nil,
        mailingListEmailTypes: [String]? = nil
    ) {
        self.userId = userId
        self.email = email
        self.notifyStatusChange = notifyStatusChange
        self.subscribeToMailingList = subscribeToMailingList
        self.mailingListEmailTypes = mailingListEmailTypes
    }
}

// MARK: - Response

public struct VoteResponse: Content, Sendable {
    public let feedbackId: UUID
    public let voteCount: Int
    public let hasVoted: Bool
}
