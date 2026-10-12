import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// The result of sending one value through a query builder and reading it back
/// with the server's own parser semantics. A named `Equatable` type, because
/// `#expect` over an array of tuples does not compile — and because the whole
/// observed vector is asserted **once**, so several real failures are reported
/// together instead of collapsing onto one source line.
struct QueryRoundTrip: Equatable, CustomStringConvertible {
    let sent: String
    let readBack: String
    let pairCount: Int

    var description: String { "\(sent) -> \(readBack) in \(pairCount) pair(s)" }
}

/// METRICS03 phase 06 — query encoding. The oracle is a **round trip under the
/// server's own parser semantics**, never "the string looks encoded".
@Suite("VaporSDK query encoding")
struct VaporSDKQueryEncodingSuite {

    // MARK: - The corpus of hostile values.
    //
    // The first five break the joined-string builder this phase replaced; the
    // last three are CONTROLS that already round-tripped, and they are here to
    // prove the gate discriminates. A space, an accent and an emoji all
    // survived naive concatenation — which is exactly why the obvious test
    // would have been green against the broken builder.

    static let breaking = [
        "a&b=c",                      // reserved delimiter — injects a parameter
        "a#b",                        // fragment delimiter — truncates
        "a+b",                        // Vapor plus-decodes `+` into a space
        "100%20done",                 // literal percent — double-decodes
        "my event & more · ünïcode",  // the spec case; fails only via the `&`
    ]
    static let controls = [
        "my event",
        "ünïcode · dot",
        "a?b",
    ]
    static var hostileValues: [String] { breaking + controls }

    /// Vapor's `URLEncodedFormParser` semantics for a flat query: its very
    /// first statement replaces `+` with `%20`, and only then does it percent
    /// decode. Replicated here so the oracle is the server's reading, not ours.
    private func serverReading(_ query: String) -> [(key: String, value: String)] {
        let plusDecoded = query.replacingOccurrences(of: "+", with: "%20")
        return plusDecoded.split(separator: "&", omittingEmptySubsequences: false).map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawKey = String(parts[0])
            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            return (rawKey.removingPercentEncoding ?? rawKey, rawValue.removingPercentEncoding ?? rawValue)
        }
    }

    private func roundTrip(_ value: String, through query: String) -> QueryRoundTrip {
        let pairs = serverReading(query)
        return QueryRoundTrip(sent: value, readBack: pairs.first?.value ?? "", pairCount: pairs.count)
    }

    // MARK: - G1(a): the encoder itself, unit level.

    @Test func encoderRoundTripsEveryHostileValue() throws {
        let values = Self.hostileValues
        #expect(values.count == 8, "the corpus is five breaking classes plus three controls")

        var observed: [QueryRoundTrip] = []
        for value in values {
            let encoded = try #require(URLQueryEncoding.query([URLQueryItem(name: "event_name", value: value)]))
            observed.append(roundTrip(value, through: encoded))
        }
        // Derived from the declared corpus, never seeded: every value must read
        // back as itself, in exactly one pair. An injected extra parameter is a
        // pairCount change — a presence oracle could not see it.
        let expected = values.map { QueryRoundTrip(sent: $0, readBack: $0, pairCount: 1) }
        #expect(observed == expected)
    }

    // MARK: - G1(b): the same values through the REAL transport, so the URI
    // parse (which is where a raw `#` truncates) is in the loop.

    struct ProbeResponse: Content {
        let ok: Bool?
    }

    @Test func hostileValuesSurviveTheRealTransport() async throws {
        let values = Self.hostileValues
        var observed: [QueryRoundTrip] = []
        var emptyURIs: [String] = []

        for value in values {
            let stub = StubClient()
            let client = makeStubbedClient(stub: stub)
            let _: ProbeResponse? = try? await client.get(
                path: "/events",
                queryItems: [URLQueryItem(name: "event_name", value: value)]
            )
            let request = try #require(stub.requests.first)
            // `URI.string` is `components?.string ?? ""` — an unparseable URI
            // produces a silent request to the empty string, with no throw. No
            // measured value triggers it; this leg is what would notice.
            if request.url.string.isEmpty { emptyURIs.append(value) }
            observed.append(roundTrip(value, through: request.url.query ?? ""))
        }

        #expect(emptyURIs.isEmpty, "URI.string collapsed to the empty string for: \(emptyURIs)")
        let expected = values.map { QueryRoundTrip(sent: $0, readBack: $0, pairCount: 1) }
        #expect(observed == expected)
    }

    // MARK: - Insertion order, and the empty-list identity.

    @Test func insertionOrderIsPreservedAndNotSorted() throws {
        let items = [
            URLQueryItem(name: "status", value: "in_progress"),
            URLQueryItem(name: "category", value: "bug_report"),
            URLQueryItem(name: "includeMerged", value: "false"),
        ]
        let encoded = try #require(URLQueryEncoding.query(items))
        #expect(encoded == "status=in_progress&category=bug_report&includeMerged=false")
        #expect(serverReading(encoded).map(\.key) == ["status", "category", "includeMerged"])
    }

    @Test func emptyItemListEmitsNoQueryAtAll() async throws {
        #expect(URLQueryEncoding.query([]) == nil, "an empty list must not produce a bare '?'")

        // …and end to end, the query-carrying verb with no items sends exactly
        // what the query-less verb sends. This is the half of the byte-identity
        // claim that keeps all 121 census rows still.
        let withItems = StubClient()
        let _: ProbeResponse? = try? await makeStubbedClient(stub: withItems)
            .get(path: "/feedbacks", queryItems: [])
        let without = StubClient()
        let _: ProbeResponse? = try? await makeStubbedClient(stub: without).get(path: "/feedbacks")

        let a = try #require(withItems.requests.first).url.string
        let b = try #require(without.requests.first).url.string
        #expect(a == b)
        #expect(a == Fixed.apiBase + "/feedbacks")
    }

    // MARK: - The source-level operation census, PER FAMILY.
    //
    // Phase 06 asserted a bare total of 121 over 15 files, promising it added
    // no operation. METRICS03 phase 07 moved it to 129 over 18 — and a bare
    // total cannot see an imbalance, so the leg now compares the whole
    // per-family vector at once. Five operations in `MetricsAPI` balanced by
    // three in `AdminMetricsAPI` sums to 129 and is a defect; this sees it.
    //
    // `MetricsQuery.swift` sits under `API/` and declares **zero** operations
    // on purpose — it is the shared query builder, not a family — and it is
    // listed rather than filtered out, so the file count stays a real
    // denominator.
    //
    // The in-test census in `VaporSDKOperationCensusTests` asserts the same
    // total against the driven table; this leg is the independent source
    // reading, with the file count as its nonzero denominator.

    @Test func publicOperationCensusPerFamily() throws {
        let pattern = try NSRegularExpression(pattern: #"public func ([A-Za-z_][A-Za-z0-9_]*)\s*\("#)
        let files = try PackagePaths.swiftFiles(under: PackagePaths.apiDir)
        #expect(files.count == 18, "scanned \(files.count) files under API/ — the denominator moved")

        var observed: [FamilyOperationCount] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            observed.append(FamilyOperationCount(
                family: file.deletingPathExtension().lastPathComponent,
                count: pattern.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
            ))
        }
        observed.sort { $0.family < $1.family }

        let expected = [
            FamilyOperationCount(family: "AdminEventAPI", count: 3),
            FamilyOperationCount(family: "AdminFeedbackAPI", count: 3),
            FamilyOperationCount(family: "AdminMetricsAPI", count: 4),
            FamilyOperationCount(family: "AdminUserAPI", count: 4),
            FamilyOperationCount(family: "AuthAPI", count: 13),
            FamilyOperationCount(family: "CommentAPI", count: 3),
            FamilyOperationCount(family: "DashboardAPI", count: 2),
            FamilyOperationCount(family: "DeviceAPI", count: 4),
            FamilyOperationCount(family: "EventAPI", count: 1),
            FamilyOperationCount(family: "FeedbackAPI", count: 4),
            FamilyOperationCount(family: "IntegrationAPI", count: 56),
            FamilyOperationCount(family: "MemberAPI", count: 9),
            FamilyOperationCount(family: "MetricsAPI", count: 4),
            FamilyOperationCount(family: "MetricsQuery", count: 0),
            FamilyOperationCount(family: "ProjectAPI", count: 12),
            FamilyOperationCount(family: "SDKUserAPI", count: 1),
            FamilyOperationCount(family: "SubscriptionAPI", count: 4),
            FamilyOperationCount(family: "VoteAPI", count: 2),
        ]
        #expect(observed == expected)
        // The total is DERIVED from the vector, never typed alongside it.
        #expect(observed.reduce(0) { $0 + $1.count } == 129,
                "the published operation count is \(observed.reduce(0) { $0 + $1.count })")
    }
}

/// One `API/` file's declared operation count. A named `Equatable` type so the
/// whole vector is asserted once — a per-iteration loop collapses several real
/// failures onto one source line.
struct FamilyOperationCount: Equatable, CustomStringConvertible {
    let family: String
    let count: Int

    var description: String { "\(family)=\(count)" }
}
