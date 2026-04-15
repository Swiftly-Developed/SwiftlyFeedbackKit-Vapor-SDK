import Vapor

/// Authentication operations.
public struct AuthAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// Create a new account.
    public func signup(_ request: SignupRequest) async throws -> AuthResponse {
        try await client.publicPost(path: "/auth/signup", body: request)
    }

    /// Login and receive a bearer token.
    public func login(_ request: LoginRequest) async throws -> AuthResponse {
        try await client.publicPost(path: "/auth/login", body: request)
    }

    /// Get the current authenticated user.
    public func me() async throws -> UserPublic {
        try await client.adminGet(path: "/auth/me", token: token)
    }

    /// Logout and invalidate all tokens.
    public func logout() async throws {
        try await client.adminPostNoResponse(path: "/auth/logout", token: token)
    }

    /// Verify email with a verification code.
    public func verifyEmail(_ request: VerifyEmailRequest) async throws -> VerifyEmailResponse {
        try await client.publicPost(path: "/auth/verify-email", body: request)
    }

    /// Resend the email verification code.
    public func resendVerification() async throws -> MessageResponse {
        try await client.adminPostEmpty(path: "/auth/resend-verification", token: token)
    }

    /// Change the current user's password.
    public func changePassword(_ request: ChangePasswordRequest) async throws {
        try await client.adminPostNoResponse(path: "/auth/password", token: token)
    }

    /// Delete the current user's account.
    public func deleteAccount(_ request: DeleteAccountRequest) async throws {
        try await client.adminDeleteWithBody(path: "/auth/account", body: request, token: token)
    }

    /// Request a password reset email.
    public func forgotPassword(_ request: ForgotPasswordRequest) async throws -> MessageResponse {
        try await client.publicPost(path: "/auth/forgot-password", body: request)
    }

    /// Reset password using a reset code.
    public func resetPassword(_ request: ResetPasswordRequest) async throws -> MessageResponse {
        try await client.publicPost(path: "/auth/reset-password", body: request)
    }

    /// Update notification preferences.
    public func updateNotifications(_ request: UpdateNotificationSettingsRequest) async throws -> UserPublic {
        try await client.adminPatch(path: "/auth/notifications", body: request, token: token)
    }

    /// Get current subscription info.
    public func subscription() async throws -> SubscriptionInfo {
        try await client.adminGet(path: "/auth/subscription", token: token)
    }

    /// Sync subscription status with the server.
    public func syncSubscription() async throws -> SubscriptionInfo {
        try await client.adminPostEmpty(path: "/auth/subscription/sync", token: token)
    }
}
