import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// Wire bugs measured against the server on `dev` (11 Oct 2026).
/// Each test names the server symbol it disagrees with.
struct VaporSDKWireContractTests {

    @Test func changePasswordPutsEncodedPasswords() async throws {
        let stub = StubClient()
        let admin = makeAdmin(stub: stub)
        _ = try? await admin.auth.changePassword(
            ChangePasswordRequest(currentPassword: "old-password", newPassword: "new-password")
        )

        let request = try #require(stub.requests.first)
        let wire = try passwordWire(request)
        // AuthController registers PUT /auth/password and decodes ChangePasswordDTO.
        #expect(wire.method == "PUT")
        #expect(wire.keys.sorted() == ["current_password", "new_password"])
        #expect(wire.currentPassword == "old-password")
        #expect(wire.newPassword == "new-password")
    }

    @Test func commentCreateSendsCreatorHeader() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        _ = try? await sdk.comments.create(
            feedbackId: Fixed.idA,
            request: CreateCommentRequest(content: "Please add dark mode.", userId: "fixture-end-user")
        )

        let request = try #require(stub.requests.first)
        // CommentController.index/create 404 hidden-over-limit rows unless
        // X-User-Id matches the creator. The body user id is not consulted there.
        #expect(request.headers.first(name: "X-User-Id") == "fixture-end-user")
    }

    @Test func commentListSendsCreatorHeaderWhenSupplied() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        _ = try? await sdk.comments.list(feedbackId: Fixed.idA, userId: "creator-1")

        let request = try #require(stub.requests.first)
        #expect(request.headers.first(name: "X-User-Id") == "creator-1")
    }

    @Test func commentListOmitsCreatorHeaderWhenAbsent() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        _ = try? await sdk.comments.list(feedbackId: Fixed.idA)

        let request = try #require(stub.requests.first)
        #expect(request.headers.first(name: "X-User-Id") == nil)
    }

    @Test func portalReturnUrlIsPercentEncoded() async throws {
        let stub = StubClient()
        let admin = makeAdmin(stub: stub)
        let returnUrl = "https://example.com/done?foo=1&bar=2"
        _ = try? await admin.subscriptions.portal(returnUrl: returnUrl)

        let request = try #require(stub.requests.first)
        let url = request.url.string
        // An unencoded `&` splits the query, so the server's portal return URL
        // loses everything after it (CreatePortalSessionDTO.returnUrl).
        #expect(url.contains("&bar=") == false)
        #expect(url.contains("returnUrl="))
        #expect(url.contains("%26"))
    }

    @Test func viewEventsOverviewDecodesRetentionMeta() throws {
        let withMeta = try Fixtures.data("view-events-overview-with-meta")
        let overview = try FeedbackKitClient.decoder.decode(ViewEventsOverview.self, from: withMeta)
        #expect(overview.eventScope == "predefined_only")
        #expect(overview.retentionClamped == true)
        #expect(overview.retentionWindowDays == 30)

        let withoutMeta = try Fixtures.data("view-events-overview-without-meta")
        let older = try FeedbackKitClient.decoder.decode(ViewEventsOverview.self, from: withoutMeta)
        #expect(older.eventScope == nil)
        #expect(older.retentionClamped == nil)
        #expect(older.retentionWindowDays == nil)
    }

    @Test func feedbackResponseDecodesSyncStates() throws {
        let withStates = try Fixtures.data("feedback-with-sync-states")
        let item = try FeedbackKitClient.decoder.decode(FeedbackResponse.self, from: withStates)
        let state = try #require(item.syncStates?.first)
        #expect(state.provider == "github")
        #expect(state.state == "pending")
        #expect(state.providerRefUrl == "https://example.com/1")

        let withoutStates = try Fixtures.data("feedback-without-sync-states")
        let older = try FeedbackKitClient.decoder.decode(FeedbackResponse.self, from: withoutStates)
        #expect(older.syncStates == nil)
        #expect(older.status == .testflight)
    }

    @Test func jsonCodersAreNotSharedInstances() {
        // JSONDecoder/JSONEncoder are classes. One static instance is used by
        // every concurrent request on a Vapor host.
        let firstDecoder = FeedbackKitClient.decoder
        let secondDecoder = FeedbackKitClient.decoder
        #expect(firstDecoder !== secondDecoder)
        let firstEncoder = FeedbackKitClient.encoder
        let secondEncoder = FeedbackKitClient.encoder
        #expect(firstEncoder !== secondEncoder)
    }
}

private struct PasswordWire: Sendable {
    var method: String
    var keys: [String]
    var currentPassword: String?
    var newPassword: String?
}

/// Pulls Sendable fields out of the recorded body so the test body never
/// asserts on a raw JSON dictionary.
private func passwordWire(_ request: ClientRequest) throws -> PasswordWire {
    let data: Data
    if var buffer = request.body {
        data = buffer.readData(length: buffer.readableBytes) ?? Data()
    } else {
        data = Data()
    }
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return PasswordWire(
        method: request.method.rawValue,
        keys: object.map { Array($0.keys) } ?? [],
        currentPassword: object?["current_password"] as? String,
        newPassword: object?["new_password"] as? String
    )
}
