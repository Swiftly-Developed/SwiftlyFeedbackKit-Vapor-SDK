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

public struct SyncAppleTransactionRequest: Content, Sendable {
    public let originalTransactionId: String
    public let productId: String

    public init(originalTransactionId: String, productId: String) {
        self.originalTransactionId = originalTransactionId
        self.productId = productId
    }
}

// MARK: - Dev/Testing

public struct OverrideSubscriptionTierRequest: Content, Sendable {
    public let tier: SubscriptionTier

    public init(tier: SubscriptionTier) {
        self.tier = tier
    }
}
