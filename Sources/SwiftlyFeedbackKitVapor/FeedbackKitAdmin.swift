import Vapor

/// Admin-level operations using Bearer token authentication.
/// Use this for project management, member management, dashboard analytics, and subscriptions.
public struct FeedbackKitAdmin: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// Authentication operations (login, signup, etc.).
    public var auth: AuthAPI { AuthAPI(client: client, token: token) }

    /// Project CRUD and settings.
    public var projects: ProjectAPI { ProjectAPI(client: client, token: token) }

    /// Project member management.
    public var members: MemberAPI { MemberAPI(client: client, token: token) }

    /// Dashboard analytics.
    public var dashboard: DashboardAPI { DashboardAPI(client: client, token: token) }

    /// Subscription management.
    public var subscriptions: SubscriptionAPI { SubscriptionAPI(client: client, token: token) }

    /// Push notification device management.
    public var devices: DeviceAPI { DeviceAPI(client: client, token: token) }

    /// Integration settings.
    public var integrations: IntegrationAPI { IntegrationAPI(client: client, token: token) }

    /// SDK user listing and stats (admin view).
    public var users: AdminUserAPI { AdminUserAPI(client: client, token: token) }

    /// Event stats (admin view).
    public var events: AdminEventAPI { AdminEventAPI(client: client, token: token) }

    /// Feedback operations requiring admin auth (update, delete, merge).
    public var feedback: AdminFeedbackAPI { AdminFeedbackAPI(client: client, token: token) }
}
