import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// One driven error, labelled. A named `Equatable` type so the whole observed
/// vector is asserted once — nine separate expectations would hide a second
/// unintended move behind the first.
struct ErrorMapping: Equatable, CustomStringConvertible {
    let label: String
    let mapped: String

    var description: String { "\(label) -> \(mapped)" }
}

/// Whether one enveloped corpus row carries a `field`.
struct FieldPresence: Equatable, CustomStringConvertible {
    let row: Int
    let hasField: Bool

    var description: String { "row \(row) field=\(hasField)" }
}

/// METRICS03 phase 06 — the two error bodies and the vocabulary they carry.
/// Every body here comes from the shared wire corpus or from the product's own
/// encoder; nothing is hand-written.
@Suite("VaporSDK metrics error vocabulary")
struct VaporSDKMetricsErrorSuite {

    // MARK: - Driving

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

    enum CorpusLookup: Error {
        case noEnvelopedRow(String)
        case noMiddlewareRow(String)
    }

    /// The bytes of the enveloped row carrying `code` — located by searching the
    /// corpus, never by a hardcoded index, so a reordered corpus cannot silently
    /// swap what a leg is asserting.
    private func envelopedRowIndex(code: String) throws -> Int {
        let rows = try Fixtures.envelopedErrorRows()
        guard let index = rows.firstIndex(where: { detail(of: $0)?["code"] as? String == code }) else {
            throw CorpusLookup.noEnvelopedRow(code)
        }
        return index
    }

    private func envelopedBody(code: String) throws -> Data {
        try Fixtures.errorRowBytes(try envelopedRowIndex(code: code), section: "enveloped")
    }

    /// The verbatim wire body of the shared-layer row carrying `reason`.
    ///
    /// Middleware rows are `{http_status, source, body}`; `body` is the bare wire body.
    /// Selection is by reason — never by index — and `middlewareStatus(reason:)` reads
    /// the status off the same row rather than restating `C6`'s prose.
    private func middlewareBody(reason: String) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: try middlewareRow(reason: reason)["body"] as Any,
            options: [.sortedKeys]
        )
    }

    /// The status that same row is served at, straight off the row.
    private func middlewareStatus(reason: String) throws -> HTTPStatus {
        guard let code = try middlewareRow(reason: reason)["http_status"] as? Int else {
            throw CorpusLookup.noMiddlewareRow(reason)
        }
        return HTTPStatus(statusCode: code)
    }

    private func middlewareRow(reason: String) throws -> [String: Any] {
        let rows = try Fixtures.middlewareErrorRows()
        guard let row = rows.first(where: {
            ($0["body"] as? [String: Any])?["reason"] as? String == reason
        }) else {
            throw CorpusLookup.noMiddlewareRow(reason)
        }
        return row
    }

    private func detail(of row: [String: Any]) -> [String: Any]? {
        row["error"] as? [String: Any]
    }

    private func jsonTypeName(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "null" }
        if value is [String: Any] { return "object" }
        if value is [Any] { return "array" }
        if let number = value as? NSNumber {
            return JSONNumberKind.isBoolean(number) ? "boolean" : "number"
        }
        if value is String { return "string" }
        return "unknown"
    }

    // MARK: - G3-1: cardinality 2. A one-shape decoder passes any presence
    // oracle; this is the assertion that sees it.

    @Test func theCorpusCarriesExactlyTwoErrorBodyShapes() throws {
        let enveloped = try Fixtures.envelopedErrorRows()
        let middleware = try Fixtures.middlewareErrorRows()
        #expect(!enveloped.isEmpty, "the enveloped section is empty — the scan read nothing")
        #expect(!middleware.isEmpty, "the middleware section is empty — the scan read nothing")

        // Middleware rows WRAP the wire body under `body`; enveloped rows ARE it.
        let middlewareBodies = middleware.compactMap { $0["body"] as? [String: Any] }
        #expect(middlewareBodies.count == middleware.count, "every middleware row carries a body")

        var shapes: Set<String> = []
        for row in enveloped + middlewareBodies {
            shapes.insert(jsonTypeName(row["error"]))
        }
        #expect(shapes == ["object", "boolean"], "observed error-value shapes: \(shapes.sorted())")
    }

    // MARK: - G3-2/3/4: 402 and 403 arrive in BOTH shapes, and must land on
    // different cases. Branching on the status alone cannot do this.

    @Test func eachShapeAndStatusPairMapsToItsOwnCase() async throws {
        var observed: [ErrorMapping] = []

        observed.append(ErrorMapping(label: "402 shape A", mapped: caseName(
            try await thrownError(status: .paymentRequired,
                                  body: try envelopedBody(code: "METRICS_CUSTOM_EVENTS_REQUIRE_PRO")))))
        observed.append(ErrorMapping(label: "402 shape B", mapped: caseName(
            try await thrownError(status: .paymentRequired,
                                  body: try errorEnvelope(reason: "Free plan limit reached")))))
        observed.append(ErrorMapping(label: "403 shape A", mapped: caseName(
            try await thrownError(status: .forbidden,
                                  body: try envelopedBody(code: "METRICS_MEASURE_REQUIRES_BEARER")))))
        observed.append(ErrorMapping(label: "403 shape B role", mapped: caseName(
            try await thrownError(status: .forbidden,
                                  body: try middlewareBody(reason: "You don't have access to this project")))))
        observed.append(ErrorMapping(label: "403 shape B suspended", mapped: caseName(
            try await thrownError(status: .forbidden,
                                  body: try middlewareBody(reason: "This project is suspended.")))))
        observed.append(ErrorMapping(label: "429 shape B", mapped: caseName(
            try await thrownError(status: .tooManyRequests,
                                  body: try middlewareBody(reason: "Too many requests. Try again later.")))))
        observed.append(ErrorMapping(label: "401 shape B", mapped: caseName(
            try await thrownError(status: .unauthorized,
                                  body: try middlewareBody(reason: "Invalid API key")))))
        // An enveloped code the client does not special-case still falls through
        // to the status mapping — the envelope arms widen nothing.
        observed.append(ErrorMapping(label: "400 shape A", mapped: caseName(
            try await thrownError(status: .badRequest,
                                  body: try envelopedBody(code: "METRICS_UNKNOWN_MEASURE")))))

        let expected = [
            ErrorMapping(label: "402 shape A", mapped: "tierUpgradeRequired"),
            ErrorMapping(label: "402 shape B", mapped: "paymentRequired"),
            ErrorMapping(label: "403 shape A", mapped: "measureNotAvailable"),
            ErrorMapping(label: "403 shape B role", mapped: "forbidden"),
            ErrorMapping(label: "403 shape B suspended", mapped: "forbidden"),
            ErrorMapping(label: "429 shape B", mapped: "rateLimited"),
            ErrorMapping(label: "401 shape B", mapped: "invalidApiKey"),
            ErrorMapping(label: "400 shape A", mapped: "badRequest"),
        ]
        #expect(observed == expected)
    }

    // MARK: - G3-5: set equality over the vocabulary. A count alone cannot see
    // a misspelling that preserves the count.

    @Test func theClientRecognisesExactlyTheCorpusVocabulary() throws {
        let rows = try Fixtures.vocabularyRows()
        #expect(!rows.isEmpty, "the vocabulary section is empty — the scan read nothing")

        let onTheWire = Set(rows.compactMap { $0["wire_token"] as? String })
        let recognised = Set(MetricsErrorCode.allCases.map(\.rawValue))
        #expect(onTheWire == recognised,
                "on the wire but unrecognised: \(onTheWire.subtracting(recognised).sorted()); recognised but not on the wire: \(recognised.subtracting(onTheWire).sorted())")
        #expect(onTheWire.count == 17, "the wire vocabulary is \(onTheWire.count) tokens")
        // The server's detailed vocabulary is wider than what it spells on the
        // wire — three Pro refusals share one token. Asserted so the 17 is
        // understood as a collapse, not as a miscount.
        let detailed = Set(rows.compactMap { $0["detailed_token"] as? String })
        #expect(detailed.count > onTheWire.count)
    }

    // MARK: - G3-6: the enveloped payload reaches the case, and `field`
    // presence tracks the corpus row by row.

    @Test func envelopePayloadReachesTheCase() async throws {
        let rows = try Fixtures.envelopedErrorRows()

        let measureIndex = try envelopedRowIndex(code: "METRICS_MEASURE_REQUIRES_BEARER")
        let measureDetail = try #require(detail(of: rows[measureIndex]))
        let measureError = try await thrownError(
            status: .forbidden,
            body: try Fixtures.errorRowBytes(measureIndex, section: "enveloped")
        )
        guard case .measureNotAvailable(let measure, let measureMessage) = measureError else {
            Issue.record("expected .measureNotAvailable, got .\(caseName(measureError))")
            return
        }
        #expect(measureMessage == measureDetail["message"] as? String)
        #expect(measure == measureDetail["field"] as? String)

        let tierIndex = try envelopedRowIndex(code: "METRICS_CUSTOM_EVENTS_REQUIRE_PRO")
        let tierDetail = try #require(detail(of: rows[tierIndex]))
        let tierError = try await thrownError(
            status: .paymentRequired,
            body: try Fixtures.errorRowBytes(tierIndex, section: "enveloped")
        )
        guard case .tierUpgradeRequired(let code, let tierMessage) = tierError else {
            Issue.record("expected .tierUpgradeRequired, got .\(caseName(tierError))")
            return
        }
        #expect(code == tierDetail["code"] as? String)
        #expect(tierMessage == tierDetail["message"] as? String)
    }

    @Test func envelopeFieldPresenceMatchesTheCorpus() throws {
        let rows = try Fixtures.envelopedErrorRows()
        #expect(!rows.isEmpty, "the enveloped section is empty — the scan read nothing")

        var observed: [FieldPresence] = []
        var expected: [FieldPresence] = []
        for (index, row) in rows.enumerated() {
            let keys = Set((detail(of: row) ?? [:]).keys)
            expected.append(FieldPresence(row: index, hasField: keys.contains("field")))
            let decoded = try FeedbackKitClient.decoder.decode(
                ErrorEnvelopeDTO.self,
                from: try Fixtures.errorRowBytes(index, section: "enveloped")
            )
            observed.append(FieldPresence(row: index, hasField: decoded.error.field != nil))
        }
        #expect(observed == expected)
        #expect(expected.contains { $0.hasField }, "the corpus must carry a field-present row")
        #expect(expected.contains { !$0.hasField }, "the corpus must carry a field-absent row")
    }

    // MARK: - G4: the eight unchanged status rows really are unchanged. Driven
    // with the BOOLEAN body, asserted as one vector.

    @Test func theBooleanShapeStatusVectorMovedOnlyAt429() async throws {
        let statuses = [400, 402, 403, 404, 409, 422, 429, 500, 503]
        var observed: [ErrorMapping] = []
        for code in statuses {
            let error = try await thrownError(
                status: HTTPResponseStatus(statusCode: code),
                body: try errorEnvelope(reason: "Fixture reason")
            )
            observed.append(ErrorMapping(label: "\(code)", mapped: caseName(error)))
        }
        let expected = [
            ErrorMapping(label: "400", mapped: "badRequest"),
            ErrorMapping(label: "402", mapped: "paymentRequired"),
            ErrorMapping(label: "403", mapped: "forbidden"),
            ErrorMapping(label: "404", mapped: "notFound"),
            ErrorMapping(label: "409", mapped: "conflict"),
            // 422 stays pinned as shipped: no arm, it falls through `default`.
            ErrorMapping(label: "422", mapped: "serverError"),
            // The single re-anchored row (METRICS03 phase 06).
            ErrorMapping(label: "429", mapped: "rateLimited"),
            ErrorMapping(label: "500", mapped: "serverError"),
            ErrorMapping(label: "503", mapped: "serverError"),
        ]
        #expect(observed == expected)
    }

    // MARK: - G5: the enum's three switches are total, derived not enumerated.
    //
    // The compiler already enforces exhaustiveness, so this gate's real job is
    // making a fifteenth case someone adds later visible as a set difference
    // rather than as three compile errors they fix without thinking.

    private func commentStripped(_ url: URL) throws -> String {
        var text = try String(contentsOf: url, encoding: .utf8)
        while let start = text.range(of: "/*"), let end = text.range(of: "*/", range: start.upperBound..<text.endIndex) {
            text.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return text.components(separatedBy: "\n").map { line -> String in
            guard let marker = line.range(of: "//") else { return line }
            return String(line[line.startIndex..<marker.lowerBound])
        }.joined(separator: "\n")
    }

    private func armLabels(in body: String) throws -> Set<String> {
        let armPattern = try NSRegularExpression(pattern: #"(?m)^\s*case ([^:\n]*):"#)
        let labelPattern = try NSRegularExpression(pattern: #"\.([a-z][A-Za-z0-9_]*)"#)
        var labels: Set<String> = []
        for match in armPattern.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
            guard let armRange = Range(match.range(at: 1), in: body) else { continue }
            let arm = String(body[armRange])
            for label in labelPattern.matches(in: arm, range: NSRange(arm.startIndex..., in: arm)) {
                guard let range = Range(label.range(at: 1), in: arm) else { continue }
                labels.insert(String(arm[range]))
            }
        }
        return labels
    }

    @Test func everyErrorCaseIsCoveredByAllThreeSwitches() throws {
        let errorFile = PackagePaths.sourcesDir.appendingPathComponent("Configuration/FeedbackKitError.swift")
        let harnessFile = PackagePaths.testsDir.appendingPathComponent("Support/Harness.swift")
        let errorSource = try commentStripped(errorFile)
        let harnessSource = try commentStripped(harnessFile)

        let marker = "extension FeedbackKitError"
        let parts = errorSource.components(separatedBy: marker)
        #expect(parts.count == 2, "expected exactly one '\(marker)' in the source, found \(parts.count - 1)")
        let enumBody = parts[0]
        let conformance = parts[1]

        let declaredPattern = try NSRegularExpression(pattern: #"(?m)^\s*case ([a-z][A-Za-z0-9_]*)"#)
        var declared: Set<String> = []
        for match in declaredPattern.matches(in: enumBody, range: NSRange(enumBody.startIndex..., in: enumBody)) {
            guard let range = Range(match.range(at: 1), in: enumBody) else { continue }
            declared.insert(String(enumBody[range]))
        }
        #expect(declared.count == 14, "declared FeedbackKitError cases: \(declared.count) — \(declared.sorted())")

        let reasonSplit = conformance.components(separatedBy: "public var reason")
        #expect(reasonSplit.count == 2, "expected exactly one 'public var reason'")
        let statusSwitch = reasonSplit[0]
        let reasonSwitch = reasonSplit[1]

        let caseNameSplit = harnessSource.components(separatedBy: "func caseName")
        #expect(caseNameSplit.count == 2, "expected exactly one 'func caseName' in the harness")
        let caseNameSwitch = caseNameSplit[1]

        let statusArms = try armLabels(in: statusSwitch)
        let reasonArms = try armLabels(in: reasonSwitch)
        let caseNameArms = try armLabels(in: caseNameSwitch)
        #expect(statusArms == declared, "AbortError.status arms: \(statusArms.symmetricDifference(declared).sorted())")
        #expect(reasonArms == declared, "AbortError.reason arms: \(reasonArms.symmetricDifference(declared).sorted())")
        #expect(caseNameArms == declared, "harness caseName arms: \(caseNameArms.symmetricDifference(declared).sorted())")
    }
}
