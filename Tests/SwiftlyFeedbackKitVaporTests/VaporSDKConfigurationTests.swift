import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// QA-UNIT12 Part F — configuration, and the two host-integration extensions.
@Suite("VaporSDK configuration and host extensions")
struct VaporSDKConfigurationSuite {

    // MARK: - -23: FeedbackKitEnvironment — five cases, each baseURL, and
    // apiBaseURL appending exactly `api/v1`. This is the only SDK of six with
    // `.custom`, and one of only two with a `development` host.

    @Test func environmentHostsArePinned() {
        #expect(FeedbackKitEnvironment.local.baseURL.absoluteString == "http://localhost:8080")
        #expect(FeedbackKitEnvironment.development.baseURL.absoluteString == "https://api.dev.getfeedbackkit.com")
        #expect(FeedbackKitEnvironment.testflight.baseURL.absoluteString == "https://api.testflight.getfeedbackkit.com")
        #expect(FeedbackKitEnvironment.production.baseURL.absoluteString == "https://api.prod.getfeedbackkit.com")

        let custom = URL(string: "https://feedback.example.invalid")!
        #expect(FeedbackKitEnvironment.custom(custom).baseURL == custom, ".custom passes the integrator's URL through untouched")

        for environment: FeedbackKitEnvironment in [.local, .development, .testflight, .production, .custom(custom)] {
            #expect(environment.apiBaseURL.absoluteString == environment.baseURL.absoluteString + "/api/v1",
                    "apiBaseURL must append exactly api/v1")
        }
    }

    // MARK: - -24: the missing-key disposition, pinned as shipped — an empty
    // apiKey is accepted silently: no guard, no validation, no throw. Adding
    // validation is a deliberate visible red here, not a silent change in a
    // shipped package.

    @Test func emptyApiKeyIsAcceptedSilently() async throws {
        let configuration = FeedbackKitConfiguration(apiKey: "", environment: .production)
        #expect(configuration.apiKey.isEmpty)
        #expect(configuration.apiBaseURL == FeedbackKitEnvironment.production.apiBaseURL,
                "apiBaseURL delegates to the environment")

        // And the empty key travels all the way onto the wire, unchallenged:
        let stub = StubClient()
        let emptyKeyed = FeedbackKitSDK(client: makeStubbedClient(stub: stub, apiKey: ""))
        _ = try? await emptyKeyed.feedback.list()
        #expect(try #require(stub.requests.first).headers.first(name: "X-API-Key") == "")
    }

    // MARK: - -25: the Application extension, paired — `.notConfigured` before
    // `configure(…)`, a working SDK after, and `configuration` reads back what
    // was stored. The Application is bare: no configure(app), no Fluent, no route.

    @Test func applicationExtensionBeforeAndAfterConfigure() async throws {
        try await withTestApp { app in
            // Before: both factories throw .notConfigured, and configuration is nil.
            #expect(app.feedbackKit.configuration == nil)
            #expect(throws: FeedbackKitError.self) { _ = try app.feedbackKit.client() }
            #expect(throws: FeedbackKitError.self) { _ = try app.feedbackKit.adminClient(token: Fixed.bearerToken) }
            do {
                _ = try app.feedbackKit.client()
            } catch let error as FeedbackKitError {
                #expect(caseName(error) == "notConfigured")
            }

            // After: configure, read back, and both factories return clients.
            app.feedbackKit.configure(apiKey: Fixed.apiKey, environment: .custom(Fixed.baseURL))
            let configuration = try #require(app.feedbackKit.configuration)
            #expect(configuration.apiKey == Fixed.apiKey)
            #expect(configuration.apiBaseURL.absoluteString == Fixed.apiBase)

            let sdk = try app.feedbackKit.client()
            #expect(sdk.client.configuration.apiKey == Fixed.apiKey)
            let admin = try app.feedbackKit.adminClient(token: Fixed.bearerToken)
            #expect(admin.token == Fixed.bearerToken)

            // Reconfigure wins — storage is overwritten, not merged.
            app.feedbackKit.configure(apiKey: "test-api-key-fixture-2", environment: .production)
            #expect(app.feedbackKit.configuration?.apiKey == "test-api-key-fixture-2")
        }
    }

    // MARK: - -26: the Request extension, paired the same way — and the
    // load-bearing detail: `req.feedbackKit` reads APPLICATION storage, so a
    // per-request configuration override is impossible. Pinned as shipped.

    @Test func requestExtensionReadsApplicationStorage() async throws {
        try await withTestApp { app in
            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/fixture"),
                on: app.eventLoopGroup.next()
            )

            // Before configure: both accessors throw .notConfigured.
            do {
                _ = try request.feedbackKit
                Issue.record("expected .notConfigured before configure")
            } catch let error as FeedbackKitError {
                #expect(caseName(error) == "notConfigured")
            }
            #expect(throws: FeedbackKitError.self) { _ = try request.feedbackKitAdmin(token: Fixed.bearerToken) }

            // Configure on the APPLICATION — and the SAME pre-existing request
            // now resolves, which is the proof that the extension reads
            // application storage, not request storage.
            app.feedbackKit.configure(apiKey: Fixed.apiKey, environment: .custom(Fixed.baseURL))
            let sdk = try request.feedbackKit
            #expect(sdk.client.configuration.apiKey == Fixed.apiKey)
            let admin = try request.feedbackKitAdmin(token: Fixed.bearerToken)
            #expect(admin.token == Fixed.bearerToken)
        }
    }
}
