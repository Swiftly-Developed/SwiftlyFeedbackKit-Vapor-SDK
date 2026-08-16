import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// QA-UNIT12 Part G — the parity handoff. This suite authors the Vapor SDK's
/// conformance; QA-UNIT10 owns the contract and the comparison, and cites these
/// IDs as its sixth input.
@Suite("VaporSDK parity handoff")
struct VaporSDKParitySuite {

    // MARK: - -27: list-decode tolerance, Vapor arm — was RED ON ARRIVAL,
    // fixed 2026-08-15.
    //
    // AGENTS.md's rule: a `[Model]` list whose element has a strict enum property
    // fed by the server MUST decode via a tolerant element-drop wrapper. The
    // SDK shipped with a bare `decode([FeedbackResponse].self)`, so the
    // tolerance corpus's single unknown-status row (`quantum_launch`) poisoned
    // the whole array. `FeedbackAPI.list` now routes through the single-definition
    // `TolerantElement` wrapper (the QA-UNIT10 Flutter shape); this asserts the
    // CONTRACT — three surviving rows, in order.

    @Test func unknownStatusRowIsDroppedAndOrderSurvives() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        stub.script(status: .ok, body: try Fixtures.data("feedback-tolerance-corpus"))

        let list = try await sdk.feedback.list()
        #expect(list.count == 3, "exactly the unknown-status row is dropped")
        #expect(list.map(\.title) == ["Tolerance row one", "Tolerance row two", "Tolerance row four"],
                "surviving rows keep their order")
    }

    // The second half of -27, green today: a GENUINELY malformed row — missing
    // required key — must still throw. A wrapper that swallows every error is
    // not tolerance, it is data loss; this is the test that will keep the future
    // wrapper honest.
    @Test func genuinelyMalformedRowStillThrows() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        stub.script(status: .ok, body: try Fixtures.arrayCorpus("feedback-tolerance-corpus", removingKey: "title", fromRow: 0))

        do {
            _ = try await sdk.feedback.list()
            Issue.record("a missing required key must throw, tolerant wrapper or not")
        } catch let error as FeedbackKitError {
            #expect(caseName(error) == "decodingError")
        }
    }

    // MARK: - -28: encode-direction key contract, Vapor arm — expected green
    // today, and that is the point: it is the tripwire for the day a request
    // property gains an uppercase run or an explicit CodingKeys forks the
    // contract. Every key each request type emits through the product's own
    // encoder must be a key the server's request DTO decodes — asserted against
    // the request-side corpus (a dropped request key returns 200 with the value
    // silently missing).

    @Test func encodedRequestKeysMatchTheRequestCorpus() throws {
        var violations: [String] = []

        func census(_ shape: String, _ body: some Encodable) throws {
            let encoded = try FeedbackKitClient.encoder.encode(body)
            let object = try JSONSerialization.jsonObject(with: encoded)
            guard let dictionary = object as? [String: Any] else {
                violations.append("\(shape): did not encode to an object")
                return
            }
            let emitted = Set(dictionary.keys)
            let corpus = try Fixtures.requestKeys(shape)
            for key in emitted.subtracting(corpus) {
                violations.append("\(shape): emits '\(key)', which the server-side corpus does not decode")
            }
            for key in corpus.subtracting(emitted) {
                violations.append("\(shape): corpus key '\(key)' was not emitted by the fully-populated request")
            }
        }

        try census("create_feedback", CreateFeedbackRequest(
            title: "Add a dark theme",
            description: "The list is hard to read at night.",
            category: .featureRequest,
            userId: "fixture-end-user",
            userEmail: "fixture-user@example.invalid",
            subscribeToMailingList: true,
            mailingListEmailTypes: ["status_change"]
        ))
        try census("create_vote", CreateVoteRequest(
            userId: "fixture-end-user",
            email: "fixture-user@example.invalid",
            notifyStatusChange: true,
            subscribeToMailingList: true,
            mailingListEmailTypes: ["status_change"]
        ))
        try census("create_comment", CreateCommentRequest(
            content: "Please add dark mode.",
            userId: "fixture-end-user",
            isAdmin: false
        ))
        try census("register_sdk_user", RegisterSDKUserRequest(userId: "fixture-end-user", mrr: 42.5))
        try census("track_view_event", TrackViewEventRequest(
            eventName: "feedback_list",
            userId: "fixture-end-user",
            properties: ["source": "fixture-tab"]
        ))

        #expect(violations.isEmpty, "\(violations)")
    }

    // And the raw-value contract the request corpus pins implicitly: enum raw
    // values cross the wire as the server's snake_case tokens, untouched by the
    // key strategy (a key strategy converts KEYS, never VALUES).
    @Test func enumRawValuesAreServerTokens() {
        #expect(FeedbackCategory.featureRequest.rawValue == "feature_request")
        #expect(FeedbackCategory.bugReport.rawValue == "bug_report")
        #expect(FeedbackStatus.inProgress.rawValue == "in_progress")
        #expect(FeedbackStatus.testflight.rawValue == "testflight")
        #expect(SubscriptionStatus.gracePeriod.rawValue == "grace_period")
        #expect(SubscriptionSource.appStore.rawValue == "app_store")
    }
}
