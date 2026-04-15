import Vapor

/// Subscription management using Bearer token authentication.
public struct SubscriptionAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// Get current subscription info.
    public func get() async throws -> SubscriptionInfo {
        try await client.adminGet(path: "/subscriptions", token: token)
    }

    /// Create a Stripe checkout session.
    public func createCheckout(_ request: CreateCheckoutSessionRequest) async throws -> CheckoutSessionResponse {
        try await client.adminPost(path: "/subscriptions/checkout", body: request, token: token)
    }

    /// Get a Stripe billing portal URL.
    public func portal(returnUrl: String? = nil) async throws -> PortalSessionResponse {
        let query = returnUrl.map { "?returnUrl=\($0)" } ?? ""
        return try await client.adminGet(path: "/subscriptions/portal\(query)", token: token)
    }

    /// Sync an App Store transaction.
    public func syncApple(_ request: SyncAppleTransactionRequest) async throws -> SubscriptionInfo {
        try await client.adminPost(path: "/subscriptions/sync-apple", body: request, token: token)
    }
}
