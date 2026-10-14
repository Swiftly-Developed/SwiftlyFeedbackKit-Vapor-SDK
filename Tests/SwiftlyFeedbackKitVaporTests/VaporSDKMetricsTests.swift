import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// One driven metrics operation: where it went and which credential it carried.
/// A named `Equatable` type so the whole vector is asserted once — the hazard
/// this guards is a *pattern* across four facade pairs, and four independently
/// green rows do not say the pairing is right.
struct FacadeObservation: Equatable, CustomStringConvertible {
    let label: String
    let url: String
    let apiKeyHeader: Bool
    let bearerHeader: Bool

    var description: String { "\(label) \(url) [key=\(apiKeyHeader) bearer=\(bearerHeader)]" }
}

/// One driven metrics error: the body shape and status that produced it, and
/// the case it landed on.
struct MetricsErrorObservation: Equatable, CustomStringConvertible {
    let label: String
    let mapped: String

    var description: String { "\(label) -> \(mapped)" }
}

/// METRICS03 phase 07 — the two metrics families, their models, and the
/// vocabularies they answer with.
///
/// Every byte of input is corpus material or the product's own encoder.
@Suite("VaporSDK metrics families")
struct VaporSDKMetricsSuite {

    // MARK: - Driving helpers

    private func recordKey(
        _ body: (FeedbackKitSDK) async throws -> Void
    ) async -> ClientRequest? {
        let stub = StubClient()
        _ = try? await body(makeSDK(stub: stub))
        return stub.requests.first
    }

    private func recordBearer(
        _ body: (FeedbackKitAdmin) async throws -> Void
    ) async -> ClientRequest? {
        let stub = StubClient()
        _ = try? await body(makeAdmin(stub: stub))
        return stub.requests.first
    }

    private func observe(_ label: String, _ request: ClientRequest?) -> FacadeObservation {
        guard let request else {
            return FacadeObservation(label: label, url: "<no request issued>", apiKeyHeader: false, bearerHeader: false)
        }
        return FacadeObservation(
            label: label,
            url: request.url.string,
            apiKeyHeader: request.headers.first(name: "X-API-Key") != nil,
            bearerHeader: request.headers.bearerAuthorization != nil
        )
    }

    // MARK: - The eight operations land on their own facade, and the four
    // pairs differ ONLY by the credential and the project prefix.
    //
    // A metrics read issued with the wrong credential compiles, type-checks
    // and answers 401 in production; this SDK is the only one that can make
    // that mistake, because it is the only one spanning both realms. The four
    // pairs are driven with IDENTICAL arguments so the pairing itself is what
    // is asserted, not eight unrelated URLs.

    @Test func theFourFacadePairsDifferOnlyByCredentialAndPrefix() async {
        let project = Fixed.idA
        var observed: [FacadeObservation] = []

        observed.append(observe("key.summary", await recordKey {
            _ = try await $0.metrics.summary(measures: [.feedbackCount, .eventCount])
        }))
        observed.append(observe("bearer.summary", await recordBearer {
            _ = try await $0.metrics.summary(projectId: project, measures: [.feedbackCount, .eventCount])
        }))
        observed.append(observe("key.timeseries", await recordKey {
            _ = try await $0.metrics.timeseries(measures: [.eventCount], granularity: .day)
        }))
        observed.append(observe("bearer.timeseries", await recordBearer {
            _ = try await $0.metrics.timeseries(projectId: project, measures: [.eventCount], granularity: .day)
        }))
        observed.append(observe("key.breakdown", await recordKey {
            _ = try await $0.metrics.breakdown(measures: [.eventCount], dimension: .eventName)
        }))
        observed.append(observe("bearer.breakdown", await recordBearer {
            _ = try await $0.metrics.breakdown(projectId: project, measures: [.eventCount], dimension: .eventName)
        }))
        observed.append(observe("key.events", await recordKey {
            _ = try await $0.metrics.events(measures: [.eventCount], page: 1, perPage: 25)
        }))
        observed.append(observe("bearer.events", await recordBearer {
            _ = try await $0.metrics.events(projectId: project, measures: [.eventCount], page: 1, perPage: 25)
        }))

        let base = Fixed.apiBase
        let prefix = "/projects/\(project)"
        let summaryQuery = "/metrics/summary?measures=feedback_count,event_count"
        let timeseriesQuery = "/metrics/timeseries?measures=event_count&granularity=day"
        let breakdownQuery = "/metrics/breakdown?measures=event_count&dimension=event_name"
        let eventsQuery = "/metrics/events?measures=event_count&page=1&per_page=25"

        let expected = [
            FacadeObservation(label: "key.summary", url: base + summaryQuery, apiKeyHeader: true, bearerHeader: false),
            FacadeObservation(label: "bearer.summary", url: base + prefix + summaryQuery, apiKeyHeader: false, bearerHeader: true),
            FacadeObservation(label: "key.timeseries", url: base + timeseriesQuery, apiKeyHeader: true, bearerHeader: false),
            FacadeObservation(label: "bearer.timeseries", url: base + prefix + timeseriesQuery, apiKeyHeader: false, bearerHeader: true),
            FacadeObservation(label: "key.breakdown", url: base + breakdownQuery, apiKeyHeader: true, bearerHeader: false),
            FacadeObservation(label: "bearer.breakdown", url: base + prefix + breakdownQuery, apiKeyHeader: false, bearerHeader: true),
            FacadeObservation(label: "key.events", url: base + eventsQuery, apiKeyHeader: true, bearerHeader: false),
            FacadeObservation(label: "bearer.events", url: base + prefix + eventsQuery, apiKeyHeader: false, bearerHeader: true),
        ]
        #expect(observed == expected)
    }

    // MARK: - Query construction: the free-form value is percent-encoded, the
    // two local refusals never reach the transport, and `per_page` is clamped.

    @Test func aHostileEventNameIsPercentEncoded() async throws {
        // Every character class the shipped concatenation corrupted: `&` and
        // `=` injected a parameter, `#` truncated the rest of the URL, `+`
        // arrived as a space, a literal `%` was double-decoded.
        let hostile = "a&b=c+d%20e#f g"
        let request = try #require(await recordKey {
            _ = try await $0.metrics.summary(measures: [.eventCount], eventName: hostile)
        })
        let url = request.url.string
        #expect(url.hasPrefix(Fixed.apiBase + "/metrics/summary?measures=event_count&event_name="))
        // One `&` beyond the parameter separators — the hostile value's own
        // ampersand must NOT have become a third parameter.
        #expect(url.components(separatedBy: "&").count == 2, "the value injected a parameter: \(url)")
        #expect(!url.contains("#"), "the value truncated the URL at a fragment marker: \(url)")
        #expect(url.hasSuffix("a%26b%3Dc%2Bd%2520e%23f%20g"), "encoded tail: \(url)")
    }

    @Test func theTwoLocalRefusalsNeverReachTheTransport() async throws {
        var observed: [MetricsErrorObservation] = []

        let conflicting = StubClient()
        do {
            _ = try await makeSDK(stub: conflicting).metrics.summary(
                measures: [.eventCount], dateFrom: "2023-11-01", days: 30
            )
            Issue.record("days together with an explicit window must be refused")
        } catch let error as FeedbackKitError {
            observed.append(MetricsErrorObservation(label: "days+window", mapped: caseName(error)))
        }
        #expect(conflicting.requests.isEmpty, "the conflicting-window request must not be issued")

        let inverted = StubClient()
        do {
            _ = try await makeSDK(stub: inverted).metrics.summary(
                measures: [.eventCount], dateFrom: "2023-11-14", dateTo: "2023-11-01"
            )
            Issue.record("an inverted window must be refused")
        } catch let error as FeedbackKitError {
            observed.append(MetricsErrorObservation(label: "inverted", mapped: caseName(error)))
        }
        #expect(inverted.requests.isEmpty, "the inverted-window request must not be issued")

        #expect(observed == [
            MetricsErrorObservation(label: "days+window", mapped: "badRequest"),
            MetricsErrorObservation(label: "inverted", mapped: "badRequest"),
        ])

        // A window the SDK cannot parse is the SERVER's to reject — the local
        // check must not guess. This one goes out.
        let unparseable = StubClient()
        _ = try? await makeSDK(stub: unparseable).metrics.summary(
            measures: [.eventCount], dateFrom: "last tuesday", dateTo: "2023-11-01"
        )
        #expect(unparseable.requests.count == 1, "an unrecognised date spelling must still be sent")
    }

    @Test func perPageIsClampedClientSideButTheServerStillOwnsTheBoundary() async throws {
        let high = try #require(await recordKey {
            _ = try await $0.metrics.events(measures: [.eventCount], perPage: 5_000)
        })
        #expect(high.url.string.hasSuffix("per_page=200"), "\(high.url.string)")

        let low = try #require(await recordKey {
            _ = try await $0.metrics.events(measures: [.eventCount], perPage: 0)
        })
        #expect(low.url.string.hasSuffix("per_page=1"), "\(low.url.string)")
    }

    // MARK: - The three response shapes a plausible model gets wrong, and the
    // sparsity a plausible reader crashes on.

    @Test func granularityIsAbsentNotNullOnASummary() throws {
        let summary = try FeedbackKitClient.decoder.decode(
            MetricSummary.self, from: Fixtures.metricsRow("summary_team_all_scope")
        )
        #expect(summary.meta.granularity == nil)
        #expect(summary.meta.resolvedGranularity == nil)
        // The corpus row genuinely omits the key — it is not present-and-null.
        let raw = try #require(
            try JSONSerialization.jsonObject(with: Fixtures.metricsRow("summary_team_all_scope")) as? [String: Any]
        )
        let meta = try #require(raw["meta"] as? [String: Any])
        #expect(!meta.keys.contains("granularity"), "the D1 row must OMIT the key, not send null")
        #expect(meta.count == 8, "summary meta carries \(meta.count) keys")
    }

    @Test func aSeriesPointIsExactlyBucketAndValues() throws {
        let series = try FeedbackKitClient.decoder.decode(
            MetricSeries.self, from: Fixtures.metricsRow("timeseries_daily")
        )
        #expect(series.meta.granularity == "day")
        #expect(series.meta.resolvedGranularity == .day)
        #expect(!series.series.isEmpty, "the timeseries row carried no points — nothing was inspected")

        // Structural, not a grep: a `bucketStart` property would show up here.
        var shapes: Set<Set<String>> = []
        for point in series.series {
            shapes.insert(Set(storedProperties(of: point).map(\.name)))
        }
        #expect(shapes == [["bucket", "values"]], "series point shapes: \(shapes)")

        // Quiet buckets are PRESENT and zero-valued, so an emptiness branch
        // never fires for a quiet window.
        let allZero = series.series.filter { point in
            !point.values.isEmpty && point.values.values.allSatisfy { $0 == 0 }
        }
        #expect(allZero.count == 1, "expected exactly one all-zero bucket, saw \(allZero.count)")
    }

    @Test func aFreeTierScopedAndClampedResponseIsASuccess() throws {
        let summary = try FeedbackKitClient.decoder.decode(
            MetricSummary.self, from: Fixtures.metricsRow("summary_free_scoped_and_clamped")
        )
        #expect(summary.meta.eventScope == "predefined_only")
        #expect(summary.meta.resolvedEventScope == .predefinedOnly)
        #expect(summary.meta.retentionClamped)
        #expect(summary.meta.retentionWindowDays == 30)
        #expect(summary[.feedbackCount] == 10)
        // The window bounds survive as the exact bytes the server sent, AND
        // parse — a `Date` property would keep only the second half.
        #expect(summary.meta.dateFrom.hasPrefix("2023-10-16"))
        #expect(summary.meta.parsedDateFrom != nil)
        #expect(summary.meta.parsedDateTo != nil)
    }

    @Test func theOverflowRowIsSparseAndTheAccessorReturnsNil() throws {
        let breakdown = try FeedbackKitClient.decoder.decode(
            MetricBreakdown.self, from: Fixtures.metricsRow("breakdown_event_name_with_overflow")
        )
        #expect(breakdown.dimension == "event_name")
        #expect(breakdown.meta.truncated)

        let overflow = breakdown.items.filter(\.isOverflow)
        let ordinary = breakdown.items.filter { !$0.isOverflow }
        #expect(overflow.count == 1, "expected exactly one overflow row, saw \(overflow.count)")
        #expect(ordinary.count == 1, "expected exactly one ordinary row, saw \(ordinary.count)")

        let full = Set(breakdown.meta.measures)
        let ordinaryKeys = Set(try #require(ordinary.first).values.keys)
        let overflowKeys = Set(try #require(overflow.first).values.keys)
        // Both directions: an extra key and a second absence are each visible.
        #expect(ordinaryKeys == full, "ordinary row keys: \(ordinaryKeys.sorted())")
        #expect(overflowKeys == full.subtracting(["unique_event_users"]),
                "overflow row keys: \(overflowKeys.sorted())")

        // The reachable production crash, in one line.
        #expect(try #require(overflow.first)[.uniqueEventUsers] == nil)
        #expect(try #require(overflow.first)[.eventCount] == 402)
    }

    @Test func theEventFeedCarriesTwoMetaBlocks() throws {
        let page = try FeedbackKitClient.decoder.decode(
            MetricEventList.self, from: Fixtures.metricsRow("events_page")
        )
        #expect(Set(storedProperties(of: page.meta).map(\.name)) == ["total", "page", "perPage", "totalPages"])
        #expect(page.meta.total == 137)
        #expect(page.meta.page == 2)
        #expect(page.meta.perPage == 50)
        #expect(page.meta.totalPages == 3)
        // The metrics block bound too — a model that put it under `meta` would
        // decode nothing here.
        #expect(page.metrics.retentionWindowDays == 30)
        #expect(page.metrics.granularity == nil)

        let withProperties = page.items.filter { $0.properties != nil }
        #expect(withProperties.count == 1, "expected one row carrying properties, saw \(withProperties.count)")
        #expect(page.items.filter { $0.properties == nil }.count == 1)

        // Verbatim, un-camelCased: `Dictionary`'s own conformance is exempt
        // from the key strategy, which is why no custom decoder may be added.
        let properties = try #require(withProperties.first?.properties)
        #expect(Set(properties.keys) == ["checkout_step", "utm_source"])
        #expect(!properties.keys.contains { $0.contains(where: \.isUppercase) },
                "a key was camelCased by a decoder: \(properties.keys.sorted())")
    }

    @Test func measureTokensSurviveTheKeyStrategyVerbatim() throws {
        let summary = try FeedbackKitClient.decoder.decode(
            MetricSummary.self, from: Fixtures.metricsRow("summary_team_all_scope")
        )
        #expect(Set(summary.values.keys) == Set(MetricMeasure.allCases.map(\.rawValue)))
        #expect(!summary.values.keys.contains { $0.contains(where: \.isUppercase) },
                "a measure token was camelCased: \(summary.values.keys.sorted())")
    }

    // MARK: - The closed vocabularies: set equality, derived from the corpus
    // wherever the corpus can say it.

    @Test func theMeasureVocabularyIsTheCorpusVocabulary() throws {
        let all = try FeedbackKitClient.decoder.decode(
            MetricSummary.self, from: Fixtures.metricsRow("summary_team_all_scope")
        )
        let declared = Set(MetricMeasure.allCases.map(\.rawValue))
        #expect(declared.count == 9, "declared measures: \(declared.count)")
        // The all-scope row resolved every measure the server serves.
        #expect(declared == Set(all.meta.measures),
                "declared but not resolved: \(declared.subtracting(all.meta.measures).sorted()); resolved but not declared: \(Set(all.meta.measures).subtracting(declared).sorted())")

        // The key-surface row resolved exactly the measures that surface serves.
        let keySurface = try FeedbackKitClient.decoder.decode(
            MetricSummary.self, from: Fixtures.metricsRow("summary_free_scoped_and_clamped")
        )
        let availableOnKey = Set(MetricMeasure.allCases.filter(\.isAvailableOnApiKey).map(\.rawValue))
        #expect(availableOnKey.count == 5, "measures marked available on the key surface: \(availableOnKey.count)")
        #expect(availableOnKey == Set(keySurface.meta.measures),
                "marked available: \(availableOnKey.sorted()); the key-surface row resolved: \(keySurface.meta.measures.sorted())")
    }

    @Test func theSmallVocabulariesAreTotalAndSpelledOnTheWire() {
        // The wire tokens, NOT the server's Swift case names (`hourly`, …).
        #expect(Set(MetricGranularity.allCases.map(\.rawValue)) == ["hour", "day", "week", "month"])
        #expect(MetricGranularity.allCases.count == 4)
        #expect(Set(MetricDimension.allCases.map(\.rawValue)) == ["status", "category", "event_name"])
        #expect(MetricDimension.allCases.count == 3)
        #expect(Set(MetricEventScope.allCases.map(\.rawValue)) == ["all", "predefined_only"])
        #expect(MetricEventScope.allCases.count == 2)
    }

    @Test func theReservedEventNamesAreExactlyTheOnesTheCorporaCarry() throws {
        let observed = try Fixtures.eventNameValues(inCorpora: [
            "event-wire-corpus", "metrics-wire-corpus", "request-wire-corpus",
        ])
        #expect(!observed.isEmpty, "no event_name value was found — the walk read nothing")

        let reserved = Set(PredefinedEventName.allCases.map(\.rawValue))
        #expect(reserved.count == 3, "reserved names: \(reserved.count)")
        // A misspelt constant stops being a subset…
        #expect(reserved.isSubset(of: observed),
                "declared but absent from every corpus: \(reserved.subtracting(observed).sorted())")
        // …and a MISSING constant shows up on the other side, because the only
        // event name the corpora carry that is not reserved is the deliberate
        // custom one behind the Pro gate.
        #expect(observed.subtracting(reserved) == ["checkout_completed"],
                "unreserved corpus event names: \(observed.subtracting(reserved).sorted())")
    }

    // MARK: - The two error bodies, on the realm each is reachable from.
    //
    // The role-denial 403 is only reachable on the Bearer realm, and it is the
    // shape carrying no machine-readable code — so it must stay distinct from
    // the key realm's measure refusal, which is the other 403. Phase 06 pins
    // the mapping table itself; this pins it through the metrics operations,
    // on the facade each error can actually arrive at.

    private func envelopedBody(code: String) throws -> Data {
        let rows = try Fixtures.envelopedErrorRows()
        guard let index = rows.firstIndex(where: {
            (($0["error"] as? [String: Any])?["code"] as? String) == code
        }) else {
            throw Fixtures.FixtureError.shape("metrics-error-wire-corpus/enveloped/" + code)
        }
        return try Fixtures.errorRowBytes(index, section: "enveloped")
    }

    /// The verbatim wire body of the shared-layer row carrying `reason`. Rows are
    /// `{http_status, source, body}` and are selected by content, never by index.
    private func middlewareBody(reason: String) throws -> Data {
        let rows = try Fixtures.middlewareErrorRows()
        guard let row = rows.first(where: {
            ($0["body"] as? [String: Any])?["reason"] as? String == reason
        }), let body = row["body"] else {
            throw Fixtures.FixtureError.shape("metrics-error-wire-corpus/middleware/" + reason)
        }
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    @Test func bothErrorShapesLandOnDistinctCasesThroughTheMetricsOperations() async throws {
        var observed: [MetricsErrorObservation] = []

        func viaKey(_ label: String, _ status: HTTPResponseStatus, _ body: Data) async {
            let stub = StubClient()
            stub.script(status: status, body: body)
            do {
                _ = try await makeSDK(stub: stub).metrics.summary(measures: [.mrrSum])
                Issue.record("\(label) must throw")
            } catch let error as FeedbackKitError {
                observed.append(MetricsErrorObservation(label: label, mapped: caseName(error)))
            } catch {
                Issue.record("\(label): unexpected \(error)")
            }
        }

        func viaBearer(_ label: String, _ status: HTTPResponseStatus, _ body: Data) async {
            let stub = StubClient()
            stub.script(status: status, body: body)
            do {
                _ = try await makeAdmin(stub: stub).metrics.breakdown(
                    projectId: Fixed.idA, measures: [.eventCount], dimension: .eventName
                )
                Issue.record("\(label) must throw")
            } catch let error as FeedbackKitError {
                observed.append(MetricsErrorObservation(label: label, mapped: caseName(error)))
            } catch {
                Issue.record("\(label): unexpected \(error)")
            }
        }

        // Shape A, key realm: the measure the key surface refuses.
        await viaKey("key 403 shape A", .forbidden, try envelopedBody(code: "METRICS_MEASURE_REQUIRES_BEARER"))
        // Shape B, Bearer realm: the role denial, no machine-readable code.
        await viaBearer("bearer 403 shape B", .forbidden, try middlewareBody(reason: "You don't have access to this project"))
        // Shape A 402 on BOTH realms — the Bearer handlers call the same tier
        // guard in-handler, so this family raises the same 402 as the key one.
        await viaKey("key 402 shape A", .paymentRequired, try envelopedBody(code: "METRICS_CUSTOM_EVENTS_REQUIRE_PRO"))
        await viaBearer("bearer 402 shape A", .paymentRequired, try envelopedBody(code: "METRICS_CUSTOM_EVENTS_REQUIRE_PRO"))
        // Shape B 402: the boolean-shaped tier refusal every other surface sends.
        await viaKey("key 402 shape B", .paymentRequired, try errorEnvelope(reason: "Free plan limit reached"))
        // 429 is reachable on the key realm only; the Bearer family carries no
        // documented request limit.
        await viaKey("key 429 shape B", .tooManyRequests, try middlewareBody(reason: "Too many requests. Try again later."))
        // A 400 the SDK does not special-case still falls through to the status.
        await viaKey("key 400 shape A", .badRequest, try envelopedBody(code: "METRICS_UNKNOWN_MEASURE"))

        #expect(observed == [
            MetricsErrorObservation(label: "key 403 shape A", mapped: "measureNotAvailable"),
            MetricsErrorObservation(label: "bearer 403 shape B", mapped: "forbidden"),
            MetricsErrorObservation(label: "key 402 shape A", mapped: "tierUpgradeRequired"),
            MetricsErrorObservation(label: "bearer 402 shape A", mapped: "tierUpgradeRequired"),
            MetricsErrorObservation(label: "key 402 shape B", mapped: "paymentRequired"),
            MetricsErrorObservation(label: "key 429 shape B", mapped: "rateLimited"),
            MetricsErrorObservation(label: "key 400 shape A", mapped: "badRequest"),
        ])
    }
}
