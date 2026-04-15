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
            URL(string: "https://api.dev.getfeedbackkit.com")!
        case .testflight:
            URL(string: "https://api.testflight.getfeedbackkit.com")!
        case .production:
            URL(string: "https://api.prod.getfeedbackkit.com")!
        case .custom(let url):
            url
        }
    }

    var apiBaseURL: URL {
        baseURL.appendingPathComponent("api/v1")
    }
}
