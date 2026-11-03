import Foundation
import Logging
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// RESILIENCE01 §9.1. A paged list stops following when the server's page number
/// cannot be trusted, and always stops within 100 follow-up requests. The stub
/// answers an unscripted call with an empty body, so a client that keeps following
/// past its script fails to decode instead of hanging.
@Suite("VaporSDK list page follow")
struct VaporSDKListPageFollowSuite {
    enum ListKind: String, CaseIterable, Sendable {
        case feedback
        case comments

        /// A corpus row. The comment row is cut from the same row, because this
        /// target has no comment corpus.
        func row() throws -> [String: Any] {
            let data = try Fixtures.row(0, ofArrayCorpus: "feedback-tolerance-corpus")
            let feedback = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            switch self {
            case .feedback:
                return feedback
            case .comments:
                var comment = [String: Any]()
                comment["id"] = feedback["id"]
                comment["content"] = feedback["title"]
                comment["user_id"] = feedback["user_id"]
                comment["is_admin"] = false
                comment["created_at"] = feedback["created_at"]
                return comment
            }
        }

        var path: String {
            switch self {
            case .feedback: return "/feedbacks"
            case .comments: return "/feedbacks/\(Fixed.idA)/comments"
            }
        }

        func list(_ sdk: FeedbackKitSDK, page: Int?) async throws -> Int {
            switch self {
            case .feedback:
                return try await sdk.feedback.list(userId: userId, page: page).count
            case .comments:
                return try await sdk.comments.list(feedbackId: Fixed.idA, userId: userId, page: page).count
            }
        }
    }

    static let userId = "user-under-test"
    static let scriptLength = 300

    final class Lines: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [(Logger.Level, String)] = []

        func append(_ level: Logger.Level, _ line: String) {
            lock.lock(); defer { lock.unlock() }
            stored.append((level, line))
        }

        var stops: [(Logger.Level, String)] {
            lock.lock(); defer { lock.unlock() }
            return stored.filter { $0.1.contains("stopped following") }
        }
    }

    struct RecordingHandler: LogHandler {
        let lines: Lines
        var metadata: Logger.Metadata = [:]
        var logLevel: Logger.Level = .trace

        subscript(metadataKey key: String) -> Logger.Metadata.Value? {
            get { metadata[key] }
            set { metadata[key] = newValue }
        }

        func log(
            level: Logger.Level,
            message: Logger.Message,
            metadata: Logger.Metadata?,
            source: String,
            file: String,
            function: String,
            line: UInt
        ) {
            lines.append(level, message.description)
        }
    }

    static func makeRecordedSDK(stub: StubClient) -> (FeedbackKitSDK, Lines) {
        let lines = Lines()
        let client = FeedbackKitClient(
            client: stub,
            configuration: FeedbackKitConfiguration(apiKey: Fixed.apiKey, environment: .custom(Fixed.baseURL)),
            logger: Logger(label: "vapor-sdk-tests") { _ in RecordingHandler(lines: lines) }
        )
        return (FeedbackKitSDK(client: client), lines)
    }

    static func script(_ stub: StubClient, kind: ListKind, meta: [String: Int]?) throws {
        var body: [String: Any] = ["items": [try kind.row()]]
        if let meta { body["meta"] = meta }
        stub.script(body: try JSONSerialization.data(withJSONObject: body))
    }

    static func expectClean(_ line: String) {
        #expect(!line.contains(Fixed.apiKey))
        #expect(!line.contains(userId))
        #expect(!line.contains("fixture-end-user"))
        #expect(!line.contains("Tolerance row one"))
    }

    @Test(arguments: ListKind.allCases)
    func staleEchoStopsAfterTwoRequests(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        for _ in 1...Self.scriptLength {
            try Self.script(stub, kind: kind, meta: ["page": 1, "per_page": 1, "total_pages": 3])
        }
        let rows = try await kind.list(sdk, page: nil)
        #expect(stub.requests.count == 2)
        #expect(rows == 1)
        #expect(lines.stops.count == 1)
        let (level, line) = try #require(lines.stops.first)
        #expect(level == .warning)
        #expect(line.contains(kind.path))
        #expect(line.contains("requested page 2"))
        #expect(line.contains("received page 1"))
        Self.expectClean(line)
    }

    @Test(arguments: ListKind.allCases)
    func followUpWithoutPageStopsAndKeepsTheRows(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        try Self.script(stub, kind: kind, meta: ["page": 1, "per_page": 1, "total_pages": 3])
        for _ in 2...Self.scriptLength {
            try Self.script(stub, kind: kind, meta: ["per_page": 1, "total_pages": 3])
        }
        let rows = try await kind.list(sdk, page: nil)
        #expect(stub.requests.count == 2)
        #expect(rows == 1)
        #expect(lines.stops.count == 1)
        let (_, line) = try #require(lines.stops.first)
        #expect(line.contains("requested page 2"))
        #expect(line.contains("received page missing"))
        Self.expectClean(line)
    }

    @Test(arguments: ListKind.allCases)
    func followUpWithoutMetaStopsAndKeepsTheRows(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        try Self.script(stub, kind: kind, meta: ["page": 1, "per_page": 1, "total_pages": 3])
        try Self.script(stub, kind: kind, meta: nil)
        let rows = try await kind.list(sdk, page: nil)
        #expect(stub.requests.count == 2)
        #expect(rows == 1)
        #expect(lines.stops.count == 1)
    }

    @Test(arguments: ListKind.allCases)
    func growingTotalStopsAfterOneHundredFollowUps(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        for index in 1...Self.scriptLength {
            try Self.script(stub, kind: kind, meta: ["page": index, "per_page": 1, "total_pages": index + 1])
        }
        let rows = try await kind.list(sdk, page: nil)
        #expect(stub.requests.count == 101)
        #expect(rows == 101)
        #expect(lines.stops.count == 1)
        let (_, line) = try #require(lines.stops.first)
        #expect(line.contains("requested page 102"))
        #expect(line.contains("received page 101"))
    }

    @Test(arguments: ListKind.allCases)
    func correctServerIsReadToTheEndWithNoLine(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        for index in 1...3 {
            try Self.script(stub, kind: kind, meta: ["page": index, "per_page": 1, "total_pages": 3])
        }
        let rows = try await kind.list(sdk, page: nil)
        #expect(stub.requests.count == 3)
        #expect(rows == 3)
        #expect(lines.stops.isEmpty)
    }

    @Test(arguments: ListKind.allCases)
    func exactlyOneHundredOnePagesFinishWithNoLine(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        for index in 1...Self.scriptLength {
            try Self.script(stub, kind: kind, meta: ["page": index, "per_page": 1, "total_pages": 101])
        }
        let rows = try await kind.list(sdk, page: nil)
        #expect(stub.requests.count == 101)
        #expect(rows == 101)
        #expect(lines.stops.isEmpty)
    }

    @Test(arguments: ListKind.allCases)
    func explicitPageIsOneRequest(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        try Self.script(stub, kind: kind, meta: ["page": 2, "per_page": 1, "total_pages": 3])
        let rows = try await kind.list(sdk, page: 2)
        #expect(stub.requests.count == 1)
        #expect(rows == 1)
        #expect(lines.stops.isEmpty)
    }

    @Test(arguments: ListKind.allCases)
    func firstResponseWithoutPageIsPageOne(kind: ListKind) async throws {
        let stub = StubClient()
        let (sdk, lines) = Self.makeRecordedSDK(stub: stub)
        try Self.script(stub, kind: kind, meta: ["per_page": 1, "total_pages": 2])
        try Self.script(stub, kind: kind, meta: ["page": 2, "per_page": 1, "total_pages": 2])
        let rows = try await kind.list(sdk, page: nil)
        #expect(stub.requests.count == 2)
        #expect(rows == 2)
        #expect(lines.stops.isEmpty)
    }
}
