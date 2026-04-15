import Vapor

/// SDK user registration using X-API-Key authentication.
public struct SDKUserAPI: Sendable {
    let client: FeedbackKitClient

    /// Register or update an SDK user.
    public func register(_ request: RegisterSDKUserRequest) async throws -> SDKUserResponse {
        try await client.post(path: "/users/register", body: request)
    }
}
