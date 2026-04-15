import Vapor

// MARK: - Request

public struct RegisterDeviceRequest: Content, Sendable {
    public let token: String
    public let platform: String
    public let appVersion: String?
    public let osVersion: String?

    public init(token: String, platform: String, appVersion: String? = nil, osVersion: String? = nil) {
        self.token = token
        self.platform = platform
        self.appVersion = appVersion
        self.osVersion = osVersion
    }
}

// MARK: - Responses

public struct DeviceTokenResponse: Content, Sendable {
    public let id: UUID
    public let token: String
    public let platform: String
    public let appVersion: String?
    public let osVersion: String?
    public let createdAt: Date?
}

public struct DeviceListResponse: Content, Sendable {
    public let devices: [DeviceTokenResponse]
}
