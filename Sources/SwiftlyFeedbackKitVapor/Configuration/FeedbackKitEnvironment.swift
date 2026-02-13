import Foundation

/// Server environment for the FeedbackKit API.
public enum FeedbackKitEnvironment: Sendable {
    case local
    case development
    case testflight
    case production
    case custom(URL)

    public var baseURL: URL {
        switch self {
        case .local:
            URL(string: "http://localhost:8080")!
        case .development:
            URL(string: "https://api.feedbackkit.dev.swiftly-developed.com")!
        case .testflight:
            URL(string: "https://testflight.getfeedbackkit.com")!
        case .production:
            URL(string: "https://getfeedbackkit.com")!
        case .custom(let url):
            url
        }
    }

    var apiBaseURL: URL {
        baseURL.appendingPathComponent("api/v1")
    }
}
