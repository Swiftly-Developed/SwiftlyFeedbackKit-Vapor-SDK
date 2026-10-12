import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// QA-UNIT12 Part E — errors, which in this SDK are also responses.
@Suite("VaporSDK error mapping")
struct VaporSDKErrorSuite {

    private func thrownError(status: HTTPResponseStatus, body: Data?) async throws -> FeedbackKitError {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        stub.script(status: status, body: body)
        do {
            _ = try await sdk.feedback.get(id: Fixed.idA)
            Issue.record("expected \(status) to throw")
            throw FeedbackKitError.notConfigured // unreachable marker
        } catch let error as FeedbackKitError {
            return error
        }
    }

    // MARK: - -19: `errorForStatus` over the full status set, per status.
    // 422 is pinned AS SHIPPED: no arm, it falls through `default` to
    // `.serverError(statusCode:)` — fixing that is a deliberate visible red
    // here, not an oversight to be "corrected" in the test (F6).
    //
    // 429 was pinned the same way until METRICS03 phase 06 (2026-08-25), which
    // added the product arm. Re-anchored here in the SAME commit as the product
    // change and recorded in the CHANGELOG as a behaviour change — a 429 now
    // surfaces as `.rateLimited(message:)` rather than `.serverError(429)`.
    // Every other row is unchanged, which the vector gate in the metrics error
    // suite asserts as a whole rather than row by row.
    //
    // These bodies are the BOOLEAN shape (`errorEnvelope(reason:)`), so the
    // 400/402/403 rows exercise shape B and stay green through the two-body
    // decode — the enveloped arms key on the body's `code`, not on the status.

    @Test(arguments: [
        (400, "badRequest"),
        (402, "paymentRequired"),
        (403, "forbidden"),
        (404, "notFound"),
        (409, "conflict"),
        (422, "serverError"),
        (429, "rateLimited"),
        (500, "serverError"),
        (503, "serverError"),
    ] as [(Int, String)])
    func statusMapsToCase(code: Int, expectedCase: String) async throws {
        let error = try await thrownError(
            status: HTTPResponseStatus(statusCode: code),
            body: try errorEnvelope(reason: "Fixture reason")
        )
        #expect(caseName(error) == expectedCase)
        if case .serverError(let statusCode) = error {
            #expect(statusCode == UInt(code))
        }
        if case .badRequest(let message) = error {
            #expect(message == "Fixture reason", "the envelope reason must survive into the case")
        }
        if case .paymentRequired(let message) = error {
            #expect(message == "Fixture reason")
        }
    }

    // MARK: - -20: the 401 prose sniff, both directions. The literal is
    // `"api key"` — the Swift SDK matches `"invalid api key"`, so one server
    // rewording flips the two SDKs on different days (F7). Pinned as shipped.

    @Test func status401WithApiKeyProseIsInvalidApiKey() async throws {
        let error = try await thrownError(status: .unauthorized, body: try errorEnvelope(reason: "Invalid API Key provided"))
        #expect(caseName(error) == "invalidApiKey")
    }

    @Test func status401MatchesTheSubstringAnywhereCaseInsensitively() async throws {
        // The sniff is `lowercased().contains("api key")` — prose that merely
        // mentions an API key routes to .invalidApiKey even when the failure is
        // something else. Pinned as shipped.
        let error = try await thrownError(status: .unauthorized, body: try errorEnvelope(reason: "Your api key has expired"))
        #expect(caseName(error) == "invalidApiKey")
    }

    @Test func status401WithOtherProseIsUnauthorized() async throws {
        let error = try await thrownError(status: .unauthorized, body: try errorEnvelope(reason: "Token expired"))
        #expect(caseName(error) == "unauthorized")
    }

    @Test func status401WithNoBodyIsUnauthorized() async throws {
        let error = try await thrownError(status: .unauthorized, body: nil)
        #expect(caseName(error) == "unauthorized")
    }

    @Test func status401WithNonEnvelopeBodyIsUnauthorized() async throws {
        // Not JSON at all — the envelope decode fails, message is nil.
        let error = try await thrownError(status: .unauthorized, body: Data("### not an envelope ###".utf8))
        #expect(caseName(error) == "unauthorized")
    }

    // MARK: - -21: `decodeOrThrow`'s failure arm — a 2xx whose body does not
    // decode becomes `.decodingError`, not a serverError, not a transport throw.

    @Test func undecodable2xxBecomesDecodingError() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        stub.script(status: .ok, body: Data("### not json ###".utf8))
        do {
            _ = try await sdk.feedback.get(id: Fixed.idA)
            Issue.record("expected a decode failure")
        } catch let error as FeedbackKitError {
            guard case .decodingError(let description) = error else {
                Issue.record("expected .decodingError, got .\(caseName(error))")
                return
            }
            #expect(!description.isEmpty, "the associated string is String(describing:) of the DecodingError")
        }
    }

    @Test func empty2xxBodyOnDecodingOperationBecomesDecodingError() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        stub.script(status: .ok, body: nil)
        do {
            _ = try await sdk.feedback.get(id: Fixed.idA)
            Issue.record("expected a decode failure")
        } catch let error as FeedbackKitError {
            #expect(caseName(error) == "decodingError")
        }
    }

    // MARK: - -22: the `AbortError` conformance, pinned. This table IS the SDK's
    // public error-response contract: Vapor's `ErrorMiddleware` returns an
    // `AbortError`'s `reason` verbatim in production, so `.decodingError`'s raw
    // decoder text becomes a host app's production response body (F8 — routed
    // to product work, pinned here so the exposure is a decision, not an accident).

    @Test func abortErrorStatusAndReasonArePinned() {
        let cases: [(FeedbackKitError, HTTPResponseStatus, String)] = [
            (.badRequest(message: nil), .badRequest, "Bad request"),
            (.badRequest(message: "Fixture reason"), .badRequest, "Fixture reason"),
            (.unauthorized, .unauthorized, "Unauthorized"),
            (.invalidApiKey, .unauthorized, "Invalid API key"),
            (.paymentRequired(message: nil), .paymentRequired, "Payment required"),
            (.paymentRequired(message: "Fixture reason"), .paymentRequired, "Fixture reason"),
            (.forbidden, .forbidden, "Forbidden"),
            (.notFound, .notFound, "Not found"),
            (.conflict, .conflict, "Conflict"),
            (.serverError(statusCode: 503), .serviceUnavailable, "Server error (503)"),
            (.decodingError("boom"), .internalServerError, "Decoding error: boom"),
            (.notConfigured, .internalServerError, "FeedbackKit has not been configured. Call app.feedbackKit.configure() first."),
            // Added by the F3 fix (2026-08-15): thrown client-side, before any
            // request, by operations the SDK's auth surface can never perform.
            (.operationNotSupported("boom"), .internalServerError, "boom"),
            // Added by METRICS03 phase 06 (2026-08-25). Each new case needs an
            // arm in BOTH exhaustive switches; these rows pin what those arms
            // produce, including the nil-message fallbacks.
            (.tierUpgradeRequired(code: "METRICS_CUSTOM_EVENTS_REQUIRE_PRO", message: "Fixture reason"), .paymentRequired, "Fixture reason"),
            (.tierUpgradeRequired(code: "METRICS_CUSTOM_EVENTS_REQUIRE_PRO", message: nil), .paymentRequired, "METRICS_CUSTOM_EVENTS_REQUIRE_PRO"),
            (.tierUpgradeRequired(code: nil, message: nil), .paymentRequired, "Upgrade required"),
            (.measureNotAvailable(measure: "measures", message: "Fixture reason"), .forbidden, "Fixture reason"),
            (.measureNotAvailable(measure: "measures", message: nil), .forbidden, "Measure not available on this authentication surface (measures)"),
            (.measureNotAvailable(measure: nil, message: nil), .forbidden, "Measure not available on this authentication surface"),
            (.rateLimited(message: "Fixture reason"), .tooManyRequests, "Fixture reason"),
            (.rateLimited(message: nil), .tooManyRequests, "Too many requests"),
        ]
        for (error, expectedStatus, expectedReason) in cases {
            #expect(error.status == expectedStatus, "\(caseName(error))")
            #expect(error.reason == expectedReason, "\(caseName(error))")
        }
    }
}
