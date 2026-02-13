import Vapor

extension Request {
    /// Access FeedbackKit SDK operations (X-API-Key auth) within a request context.
    public var feedbackKit: FeedbackKitSDK {
        get throws {
            guard let config = application.storage[Application.FeedbackKitConfigurationKey.self] else {
                throw FeedbackKitError.notConfigured
            }
            let httpClient = FeedbackKitClient(
                client: client,
                configuration: config,
                logger: logger
            )
            return FeedbackKitSDK(client: httpClient)
        }
    }

    /// Access FeedbackKit admin operations (Bearer token auth) within a request context.
    public func feedbackKitAdmin(token: String) throws -> FeedbackKitAdmin {
        guard let config = application.storage[Application.FeedbackKitConfigurationKey.self] else {
            throw FeedbackKitError.notConfigured
        }
        let httpClient = FeedbackKitClient(
            client: client,
            configuration: config,
            logger: logger
        )
        return FeedbackKitAdmin(client: httpClient, token: token)
    }
}
