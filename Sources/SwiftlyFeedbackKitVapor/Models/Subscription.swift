import Vapor

// MARK: - Enums

public enum SubscriptionTier: String, Content, CaseIterable, Sendable {
    case free
    case pro
    case team
}

public enum SubscriptionStatus: String, Content, CaseIterable, Sendable {
    case active
    case expired
    case cancelled
    case gracePeriod = "grace_period"
    case paused

    public var isActive: Bool {
        self == .active || self == .gracePeriod
    }
}

public enum SubscriptionSource: String, Content, Sendable {
    case stripe
    case appStore = "app_store"
}

// MARK: - Responses

public struct SubscriptionInfo: Content, Sendable {
    public let tier: SubscriptionTier
    public let status: SubscriptionStatus?
    public let productId: String?
    public let expiresAt: Date?
    public let source: SubscriptionSource?
    public let limits: SubscriptionLimits
}

public struct SubscriptionLimits: Content, Sendable {
    public let maxProjects: Int?
    public let maxFeedbackPerProject: Int?
    public let currentProjectCount: Int
    public let canCreateProject: Bool
}

// MARK: - Stripe Requests

public struct CreateCheckoutSessionRequest: Content, Sendable {
    public let priceId: String
    public let successUrl: String?
    public let cancelUrl: String?

    public init(priceId: String, successUrl: String? = nil, cancelUrl: String? = nil) {
        self.priceId = priceId
        self.successUrl = successUrl
        self.cancelUrl = cancelUrl
    }
}

public struct CheckoutSessionResponse: Content, Sendable {
    public let checkoutUrl: String
}

public struct PortalSessionResponse: Content, Sendable {
    public let portalUrl: String
}

// MARK: - Apple Requests

/// Request for `subscriptions.syncApple`.
///
/// The server reads the product and original transaction IDs from the signed
/// transaction itself, so they are no longer sent (and would not be believed
/// if they were).
public struct SyncAppleTransactionRequest: Content, Sendable {
    /// StoreKit 2 signed transaction JWS — `VerificationResult.jwsRepresentation`
    /// for the transaction being synced.
    public let signedTransaction: String

    public init(signedTransaction: String) {
        self.signedTransaction = signedTransaction
    }
}

// MARK: - Dev/Testing

public struct OverrideSubscriptionTierRequest: Content, Sendable {
    public let tier: SubscriptionTier

    public init(tier: SubscriptionTier) {
        self.tier = tier
    }
}
