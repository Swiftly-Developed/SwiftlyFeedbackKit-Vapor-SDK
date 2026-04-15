import Vapor

// MARK: - Request

public struct TrackViewEventRequest: Content, Sendable {
    public let eventName: String
    public let userId: String
    public let properties: [String: String]?

    public init(eventName: String, userId: String, properties: [String: String]? = nil) {
        self.eventName = eventName
        self.userId = userId
        self.properties = properties
    }
}

// MARK: - Responses

public struct ViewEventResponse: Content, Sendable {
    public let id: UUID
    public let eventName: String
    public let userId: String
    public let properties: [String: String]?
    public let createdAt: Date?
}

public struct ViewEventStats: Content, Sendable {
    public let eventName: String
    public let totalCount: Int
    public let uniqueUsers: Int
}

public struct ViewEventsOverview: Content, Sendable {
    public let totalEvents: Int
    public let uniqueUsers: Int
    public let eventBreakdown: [ViewEventStats]
    public let recentEvents: [ViewEventResponse]
    public let dailyStats: [DailyEventStats]
}

public struct DailyEventStats: Content, Sendable {
    public let date: String
    public let totalCount: Int
    public let uniqueUsers: Int
    public let eventBreakdown: [String: Int]
}
