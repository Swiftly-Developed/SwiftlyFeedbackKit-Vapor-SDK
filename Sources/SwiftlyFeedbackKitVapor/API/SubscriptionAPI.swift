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
        // `returnUrl` is the query key `CreatePortalSessionDTO` decodes (the
        // form decoder does not apply the JSON snake_case strategy). The value
        // is percent-encoded so an `&` in the URL is not a second parameter.
        var query: [URLQueryItem] = []
        if let returnUrl {
            query.append(URLQueryItem(name: "returnUrl", value: returnUrl))
        }
        return try await client.adminGet(path: "/subscriptions/portal", queryItems: query, token: token)
    }

    /// Sync an App Store transaction.
    public func syncApple(_ request: SyncAppleTransactionRequest) async throws -> SubscriptionInfo {
        try await client.adminPost(path: "/subscriptions/sync-apple", body: request, token: token)
    }
}
