import Vapor

/// Push notification device management using Bearer token authentication.
public struct DeviceAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// Register a device for push notifications.
    public func register(_ request: RegisterDeviceRequest) async throws -> DeviceTokenResponse {
        try await client.adminPost(path: "/devices/register", body: request, token: token)
    }

    /// List the user's registered devices.
    public func list() async throws -> DeviceListResponse {
        try await client.adminGet(path: "/devices", token: token)
    }

    /// Delete a device by ID.
    public func delete(id: UUID) async throws {
        try await client.adminDelete(path: "/devices/\(id)", token: token)
    }

    /// Delete a device by token string.
    public func delete(token deviceToken: String) async throws {
        try await client.adminDelete(path: "/devices/token/\(deviceToken)", token: token)
    }
}
