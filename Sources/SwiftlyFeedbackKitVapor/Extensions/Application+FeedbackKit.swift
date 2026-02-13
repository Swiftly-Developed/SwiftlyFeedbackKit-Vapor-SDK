import Vapor

extension Application {
    /// Access FeedbackKit configuration and management.
    public var feedbackKit: FeedbackKit {
        .init(application: self)
    }

    /// Storage key for FeedbackKit configuration.
    struct FeedbackKitConfigurationKey: StorageKey {
        typealias Value = FeedbackKitConfiguration
    }
}

/// Top-level FeedbackKit interface on `Application`.
public struct FeedbackKit: Sendable {
    let application: Application

    /// Configure the FeedbackKit SDK with an API key and environment.
    public func configure(apiKey: String, environment: FeedbackKitEnvironment) {
        application.storage[Application.FeedbackKitConfigurationKey.self] = FeedbackKitConfiguration(
            apiKey: apiKey,
            environment: environment
        )
    }

    /// The current configuration, if set.
    public var configuration: FeedbackKitConfiguration? {
        application.storage[Application.FeedbackKitConfigurationKey.self]
    }

    /// Create an SDK client (X-API-Key auth) for use outside of a request context.
    public func client() throws -> FeedbackKitSDK {
        guard let config = configuration else {
            throw FeedbackKitError.notConfigured
        }
        let httpClient = FeedbackKitClient(
            client: application.client,
            configuration: config,
            logger: application.logger
        )
        return FeedbackKitSDK(client: httpClient)
    }

    /// Create an admin client (Bearer token auth) for use outside of a request context.
    public func adminClient(token: String) throws -> FeedbackKitAdmin {
        guard let config = configuration else {
            throw FeedbackKitError.notConfigured
        }
        let httpClient = FeedbackKitClient(
            client: application.client,
            configuration: config,
            logger: application.logger
        )
        return FeedbackKitAdmin(client: httpClient, token: token)
    }
}
