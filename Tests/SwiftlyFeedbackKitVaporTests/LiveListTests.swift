import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// End-to-end against the server `FeedbackListLiveServerTests` is holding open.
/// Disabled unless that harness exported an origin, so a normal `swift test` does not dial out.
@Suite("REL-05 live server", .enabled(if: ProcessInfo.processInfo.environment["FEEDBACKKIT_LIVE_ORIGIN"] != nil))
struct VaporSDKLiveListTests {
    @Test func sdkReadsTheEnvelopeAndALegacyArray() async throws {
        let env = ProcessInfo.processInfo.environment
        let origin = try #require(env["FEEDBACKKIT_LIVE_ORIGIN"])
        let apiKey = try #require(env["FEEDBACKKIT_LIVE_API_KEY"])
        let visibleCount = try #require(Int(env["FEEDBACKKIT_LIVE_FEEDBACK_COUNT"] ?? ""))
        let commentID = try #require(UUID(uuidString: env["FEEDBACKKIT_LIVE_COMMENT_FEEDBACK_ID"] ?? ""))
        let commentCount = try #require(Int(env["FEEDBACKKIT_LIVE_COMMENT_COUNT"] ?? ""))
        let url = try #require(URL(string: origin))

        try await withTestApp { app in
            app.feedbackKit.configure(apiKey: apiKey, environment: .custom(url))
            let sdk = try app.feedbackKit.client()

            let all = try await sdk.feedback.list()
            #expect(all.count == visibleCount)
            let page = try await sdk.feedback.list(page: 1, perPage: 5)
            #expect(page.count == 5)
            #expect(page.map(\.id) == Array(all.prefix(5).map(\.id)))

            let comments = try await sdk.comments.list(feedbackId: commentID)
            #expect(comments.count == commentCount)
            let commentPage = try await sdk.comments.list(feedbackId: commentID, page: 2, perPage: 5)
            #expect(commentPage.count == 5)
            #expect(commentPage.map(\.id) == Array(comments.dropFirst(5).prefix(5).map(\.id)))

            let legacy = try await sdk.client.getData(
                path: "/feedbacks",
                queryItems: [
                    URLQueryItem(name: "page", value: "2"),
                    URLQueryItem(name: "per_page", value: "1")
                ]
            )
            #expect(legacy.first == UInt8(ascii: "["))
            let rows = try FeedbackKitClient.decoder.decode([FeedbackResponse].self, from: legacy)
            #expect(rows.count == visibleCount)
        }
    }
}
