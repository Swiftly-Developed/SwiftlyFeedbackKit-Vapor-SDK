import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// QA-UNIT12 Part D — the transport seam: what the SDK actually sends.
@Suite("VaporSDK transport seam")
struct VaporSDKTransportSuite {

    // MARK: - -13: the seam itself. A stub `Vapor.Client` through the synthesised
    // internal memberwise init drives the real client — real headers, real URI,
    // real decode — with no SDK source change. Ordered recording, per-call scripting.

    @Test func seamDrivesTheRealClientWithScriptedResponses() async throws {
        // The real decode runs over corpus bytes, scripted per call. (VoteAPI.vote
        // decodes a single VoteResponse; script a single corpus row.)
        let stub2 = StubClient()
        let sdk2 = makeSDK(stub: stub2)
        stub2.script(status: .ok, body: try Fixtures.row(0, ofArrayCorpus: "vote-wire-corpus"))
        let vote = try await sdk2.votes.vote(
            feedbackId: Fixed.idA,
            request: CreateVoteRequest(userId: "fixture-end-user")
        )
        #expect(vote.hasVoted == true)
        #expect(vote.voteCount == 8)

        let stub = StubClient()
        let sdk = makeSDK(stub: stub)

        // Ordered recording across two calls on one stub:
        _ = try? await sdk.comments.list(feedbackId: Fixed.idA)
        _ = try? await sdk.comments.list(feedbackId: Fixed.idB)
        let paths = stub.requests.map(\.url.string)
        #expect(paths == [
            "\(Fixed.apiBase)/feedbacks/\(Fixed.idA)/comments",
            "\(Fixed.apiBase)/feedbacks/\(Fixed.idB)/comments",
        ], "requests must be recorded in call order")

        // A scripted transport failure surfaces as the underlying error — the
        // SDK maps statuses, not transport failures.
        let stub3 = StubClient()
        let sdk3 = makeSDK(stub: stub3)
        stub3.scriptFailure(FixtureTransportError())
        await #expect(throws: FixtureTransportError.self) {
            _ = try await sdk3.comments.list(feedbackId: Fixed.idA)
        }
    }

    struct FixtureTransportError: Error {}

    // MARK: - -14: URI construction across all five environments. `apiURI` is
    // string concatenation — it neither escapes nor normalises — pinned as shipped.

    @Test(arguments: [
        (FeedbackKitEnvironment.local, "http://localhost:8080/api/v1"),
        (FeedbackKitEnvironment.development, "https://api.dev.getfeedbackkit.com/api/v1"),
        (FeedbackKitEnvironment.testflight, "https://api.testflight.getfeedbackkit.com/api/v1"),
        (FeedbackKitEnvironment.production, "https://api.prod.getfeedbackkit.com/api/v1"),
        (FeedbackKitEnvironment.custom(URL(string: "https://feedback.example.invalid")!), "https://feedback.example.invalid/api/v1"),
        // .custom with a trailing slash — the integrator-supplied case:
        (FeedbackKitEnvironment.custom(URL(string: "https://feedback.example.invalid/")!), "https://feedback.example.invalid/api/v1"),
        // .custom carrying its own path:
        (FeedbackKitEnvironment.custom(URL(string: "https://feedback.example.invalid/base/")!), "https://feedback.example.invalid/base/api/v1"),
    ] as [(FeedbackKitEnvironment, String)])
    func uriConstructionPerEnvironment(environment: FeedbackKitEnvironment, expectedBase: String) async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub, environment: environment)
        _ = try? await sdk.feedback.list()
        let request = try #require(stub.requests.first)
        #expect(request.url.string == expectedBase + "/feedbacks")
    }

    @Test func uriQueryStringBranch() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        _ = try? await sdk.feedback.list(status: .inProgress, category: .bugReport, includeMerged: false)
        let full = try #require(stub.requests.first).url.string
        // Raw values cross the query as snake_case; the `includeMerged` key itself
        // is camelCase — pinned as shipped.
        #expect(full == "\(Fixed.apiBase)/feedbacks?status=in_progress&category=bug_report&includeMerged=false")

        let stub2 = StubClient()
        let sdk2 = makeSDK(stub: stub2)
        _ = try? await sdk2.feedback.list(status: .pending)
        #expect(try #require(stub2.requests.first).url.string == "\(Fixed.apiBase)/feedbacks?status=pending")
    }

    // MARK: - -15: SDK-surface headers.

    @Test func xUserIdPresentIffSupplied() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)

        _ = try? await sdk.feedback.list(userId: "fixture-end-user")
        _ = try? await sdk.feedback.list()
        // FeedbackAPI.create forwards request.userId into the header:
        _ = try? await sdk.feedback.create(CreateFeedbackRequest(
            title: "Add a dark theme",
            description: "The list is hard to read at night.",
            category: .featureRequest,
            userId: "fixture-end-user"
        ))
        // CommentAPI.create carries the user id in the body ONLY — no header.
        // Pinned as shipped (finding F4: the X-User-Id surface is inconsistent).
        _ = try? await sdk.comments.create(
            feedbackId: Fixed.idA,
            request: CreateCommentRequest(content: "Please add dark mode.", userId: "fixture-end-user")
        )

        let requests = stub.requests
        #expect(requests.count == 4)
        #expect(requests[0].headers.first(name: "X-User-Id") == "fixture-end-user")
        #expect(requests[1].headers.first(name: "X-User-Id") == nil)
        #expect(requests[2].headers.first(name: "X-User-Id") == "fixture-end-user")
        #expect(requests[3].headers.first(name: "X-User-Id") == nil)
    }

    @Test func contentTypeAppearsExactlyOnce() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)

        // GET: header builder only.
        _ = try? await sdk.feedback.list()
        // POST: header builder adds it AND the body encoder sets it again —
        // the claim is that exactly one survives.
        _ = try? await sdk.users.register(RegisterSDKUserRequest(userId: "fixture-end-user", mrr: 42.5))

        for request in stub.requests {
            let values = request.headers[canonicalForm: "content-type"]
            #expect(values.count == 1, "\(request.method) \(request.url.string) sent Content-Type \(values.count) times: \(values)")
            // Measured: the header builder adds "application/json"; on bodied
            // requests the content encoder REPLACES it with
            // "application/json; charset=utf-8" — so exactly one survives, and
            // its parameters differ by verb. Pinned by prefix.
            #expect(values.first?.hasPrefix("application/json") == true, "\(request.method): \(values)")
        }
    }

    // MARK: - -16: the two auth surfaces, paired — both halves or neither (C7).
    // (The per-operation pairing across all 121 operations is asserted by the
    // operation census; this is the explicit paired statement of the rule.)

    @Test func authSurfacesArePairedAndExclusive() async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        let admin = makeAdmin(stub: stub)

        _ = try? await sdk.feedback.list()
        _ = try? await admin.projects.list()
        _ = try? await admin.auth.login(LoginRequest(email: "fixture-user@example.invalid", password: "fixture-password"))

        let requests = stub.requests
        #expect(requests.count == 3)

        // SDK surface: X-API-Key present, Bearer absent.
        #expect(requests[0].headers.first(name: "X-API-Key") == Fixed.apiKey)
        #expect(requests[0].headers.bearerAuthorization == nil)

        // Admin surface: Bearer present, X-API-Key absent.
        #expect(requests[1].headers.bearerAuthorization?.token == Fixed.bearerToken)
        #expect(requests[1].headers.first(name: "X-API-Key") == nil)

        // Unauthenticated surface: neither.
        #expect(requests[2].headers.bearerAuthorization == nil)
        #expect(requests[2].headers.first(name: "X-API-Key") == nil)
    }
}
