import Vapor

// MARK: - Requests

public struct SignupRequest: Content, Sendable {
    public let email: String
    public let name: String
    public let password: String

    public init(email: String, name: String, password: String) {
        self.email = email
        self.name = name
        self.password = password
    }
}

public struct LoginRequest: Content, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct ChangePasswordRequest: Content, Sendable {
    public let currentPassword: String
    public let newPassword: String

    public init(currentPassword: String, newPassword: String) {
        self.currentPassword = currentPassword
        self.newPassword = newPassword
    }
}

public struct DeleteAccountRequest: Content, Sendable {
    public let password: String

    public init(password: String) {
        self.password = password
    }
}

public struct VerifyEmailRequest: Content, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

public struct ForgotPasswordRequest: Content, Sendable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct ResetPasswordRequest: Content, Sendable {
    public let code: String
    public let newPassword: String

    public init(code: String, newPassword: String) {
        self.code = code
        self.newPassword = newPassword
    }
}

public struct UpdateNotificationSettingsRequest: Content, Sendable {
    public let notifyNewFeedback: Bool?
    public let notifyNewComments: Bool?
    public let pushNotificationsEnabled: Bool?
    public let pushNotifyNewFeedback: Bool?
    public let pushNotifyNewComments: Bool?
    public let pushNotifyVotes: Bool?
    public let pushNotifyStatusChanges: Bool?

    public init(
        notifyNewFeedback: Bool? = nil,
        notifyNewComments: Bool? = nil,
        pushNotificationsEnabled: Bool? = nil,
        pushNotifyNewFeedback: Bool? = nil,
        pushNotifyNewComments: Bool? = nil,
        pushNotifyVotes: Bool? = nil,
        pushNotifyStatusChanges: Bool? = nil
    ) {
        self.notifyNewFeedback = notifyNewFeedback
        self.notifyNewComments = notifyNewComments
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.pushNotifyNewFeedback = pushNotifyNewFeedback
        self.pushNotifyNewComments = pushNotifyNewComments
        self.pushNotifyVotes = pushNotifyVotes
        self.pushNotifyStatusChanges = pushNotifyStatusChanges
    }
}

// MARK: - Responses

public struct AuthResponse: Content, Sendable {
    public let token: String
    public let user: UserPublic
}

public struct UserPublic: Content, Sendable {
    public let id: UUID
    public let email: String
    public let name: String
    public let isAdmin: Bool
    public let isEmailVerified: Bool
    public let notifyNewFeedback: Bool
    public let notifyNewComments: Bool
    public let pushNotificationsEnabled: Bool
    public let pushNotifyNewFeedback: Bool
    public let pushNotifyNewComments: Bool
    public let pushNotifyVotes: Bool
    public let pushNotifyStatusChanges: Bool
    public let subscriptionTier: SubscriptionTier
    public let subscriptionStatus: SubscriptionStatus?
    public let subscriptionExpiresAt: Date?
    public let createdAt: Date?
}

public struct VerifyEmailResponse: Content, Sendable {
    public let message: String
    public let user: UserPublic
}

public struct MessageResponse: Content, Sendable {
    public let message: String
}
