import Vapor

/// Configuration for the FeedbackKit Vapor SDK.
public struct FeedbackKitConfiguration: Sendable {
    /// The project API key (X-API-Key header).
    public let apiKey: String

    /// The server environment.
    public let environment: FeedbackKitEnvironment

    /// Resolved API base URL (e.g. `https://getfeedbackkit.com/api/v1`).
    public var apiBaseURL: URL {
        environment.apiBaseURL
    }

    public init(apiKey: String, environment: FeedbackKitEnvironment) {
        self.apiKey = apiKey
        self.environment = environment
    }
}
