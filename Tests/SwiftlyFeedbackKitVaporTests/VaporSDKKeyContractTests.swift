import Foundation
import Testing
@testable import SwiftlyFeedbackKitVapor

/// QA-UNIT12 Parts B (runtime half) and C — decode against the server's real
/// bytes, and the four-oracle key-contract census.
@Suite("VaporSDK key contract and corpus decode")
struct VaporSDKKeyContractSuite {

    // MARK: - Probes on the census machinery itself
    // ("Probe your own assertions" — a census built on a broken snake-case
    // replica is green everywhere for the wrong reason.)

    @Test func snakeCaseReplicaMatchesKnownPairs() {
        #expect(toSnakeCase("userId") == "user_id")
        #expect(toSnakeCase("totalMRR") == "total_mrr")
        #expect(toSnakeCase("usersWithMRR") == "users_with_mrr")
        #expect(toSnakeCase("slackWebhookURL") == "slack_webhook_url")
        #expect(toSnakeCase("githubIssueUrl") == "github_issue_url")
        #expect(toSnakeCase("mrr") == "mrr")
        #expect(fromSnakeCase("total_mrr") == "totalMrr")
        #expect(fromSnakeCase("user_id") == "userId")
        #expect(fromSnakeCase("mrr") == "mrr")
        // The mechanism behind F1/F2, demonstrated on the census's own tools:
        #expect(fromSnakeCase(toSnakeCase("totalMRR")) != "totalMRR")
        #expect(fromSnakeCase(toSnakeCase("userId")) == "userId")
    }

    @Test func mirrorCensusSeesStoredPropertiesOnly() throws {
        let vote = try FeedbackKitClient.decoder.decode([VoteResponse].self, from: Fixtures.data("vote-wire-corpus"))[0]
        let facts = storedProperties(of: vote)
        #expect(Set(facts.map(\.name)) == ["feedbackId", "voteCount", "hasVoted"])
        #expect(facts.allSatisfy { !$0.isOptional })
    }

    // MARK: - -08: every corpus-backed response model decodes the server's real
    // bytes through the product's own decoder, and every property binds.
    //
    // `SDKUsersStats` — the spec's red-on-arrival F1 — has NO corpus arm in the
    // shipped fixture set, and a missing corpus blocks the ID rather than
    // licensing a literal (§9.6). F1 is caught from names alone by the -12
    // census below, which is the ID built to see corpus-unreachable properties.

    @Test func voteCorpusDecodes() throws {
        let votes = try FeedbackKitClient.decoder.decode([VoteResponse].self, from: Fixtures.data("vote-wire-corpus"))
        #expect(votes.count == 2)
        #expect(votes[0].hasVoted == true)
        #expect(votes[0].voteCount == 8)
        #expect(votes[1].hasVoted == false)
        #expect(votes[1].voteCount == 0)
    }

    @Test func sdkUserCorpusDecodes() throws {
        let users = try FeedbackKitClient.decoder.decode([SDKUserResponse].self, from: Fixtures.data("sdk-user-wire-corpus"))
        #expect(users.count == 2)
        #expect(users[0].mrr == 42.5)
        #expect(users[0].firstSeenAt != nil)
        #expect(users[0].lastSeenAt != nil)
        // The absent-optional-key adversarial row:
        #expect(users[1].mrr == nil)
        #expect(users[1].firstSeenAt == nil)
    }

    @Test func eventCorpusDecodes() throws {
        let events = try FeedbackKitClient.decoder.decode([ViewEventResponse].self, from: Fixtures.data("event-wire-corpus"))
        #expect(events.count == 2)
        #expect(events[0].properties?["source"] == "fixture-tab")
        #expect(events[0].createdAt != nil)
        #expect(events[1].properties == nil)
    }

    @Test(arguments: [0, 1, 3]) func feedbackBenignRowsDecode(rowIndex: Int) throws {
        // Rows 0, 1 and 3 are the known-status rows; row 2 is -27's unknown-token
        // row and poisons a whole-array decode today (asserted there, not here).
        let row = try Fixtures.row(rowIndex, ofArrayCorpus: "feedback-tolerance-corpus")
        let feedback = try FeedbackKitClient.decoder.decode(FeedbackResponse.self, from: row)
        #expect(!feedback.title.isEmpty)
        #expect(feedback.userId == "fixture-end-user")
        #expect(feedback.createdAt != nil)
        #expect(feedback.updatedAt != nil)
    }

    // MARK: - -09: required-field census — no corpus-backed response model
    // declares a non-optional property whose key the corpus does not carry.

    @Test func requiredFieldCensus() throws {
        var violations: [String] = []
        func census(_ model: String, _ facts: [PropertyFact], _ corpusKeys: Set<String>) {
            for fact in facts where !fact.isOptional && !corpusKeys.contains(fact.wireKey) {
                violations.append("\(model).\(fact.name) requires wire key '\(fact.wireKey)' the corpus never carries")
            }
        }
        let decoder = FeedbackKitClient.decoder
        census("VoteResponse",
               storedProperties(of: try decoder.decode([VoteResponse].self, from: Fixtures.data("vote-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "vote-wire-corpus"))
        census("SDKUserResponse",
               storedProperties(of: try decoder.decode([SDKUserResponse].self, from: Fixtures.data("sdk-user-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "sdk-user-wire-corpus"))
        census("ViewEventResponse",
               storedProperties(of: try decoder.decode([ViewEventResponse].self, from: Fixtures.data("event-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "event-wire-corpus"))
        census("FeedbackResponse",
               storedProperties(of: try decoder.decode(FeedbackResponse.self, from: Fixtures.row(0, ofArrayCorpus: "feedback-tolerance-corpus"))),
               try Fixtures.keyUnion(ofArrayCorpus: "feedback-tolerance-corpus"))

        // METRICS03 phase 07 — the metrics models, censused against the key
        // UNION across every corpus row (see `Fixtures.metricsMetaKeyUnion`).
        let summary = try decoder.decode(MetricSummary.self, from: Fixtures.metricsRow("summary_team_all_scope"))
        let series = try decoder.decode(MetricSeries.self, from: Fixtures.metricsRow("timeseries_daily"))
        let breakdown = try decoder.decode(MetricBreakdown.self, from: Fixtures.metricsRow("breakdown_event_name_with_overflow"))
        let events = try decoder.decode(MetricEventList.self, from: Fixtures.metricsRow("events_page"))
        census("MetricsMeta", storedProperties(of: summary.meta), try Fixtures.metricsMetaKeyUnion())
        census("MetricSeriesPoint",
               storedProperties(of: try #require(series.series.first)),
               try Fixtures.metricsArrayKeyUnion("series", ofRow: "timeseries_daily"))
        census("MetricBreakdownItem",
               storedProperties(of: try #require(breakdown.items.first)),
               try Fixtures.metricsArrayKeyUnion("items", ofRow: "breakdown_event_name_with_overflow"))
        census("MetricPaginationMeta",
               storedProperties(of: events.meta),
               try Fixtures.metricsObjectKeys("meta", ofRow: "events_page"))
        #expect(violations.isEmpty, "\(violations)")
    }

    // MARK: - -10: phantom-key census, the silent half — an optional property
    // whose key the corpus never carries decodes to a permanently-nil value.
    //
    // Scoped to the models whose corpus carries their full optional surface.
    // FeedbackResponse's 30+ optionals have no corpus rows (a QA-UNIT10 -03/-07
    // adversity gap, reported), and ProjectResponse — the spec's red-on-arrival
    // F2, `slackWebhookUrl` (né `slackWebhookURL`) — has no corpus at all;
    // F2 was caught by -12 below and fixed 2026-08-15.

    @Test func phantomKeyCensus() throws {
        var violations: [String] = []
        func census(_ model: String, _ facts: [PropertyFact], _ corpusKeys: Set<String>) {
            for fact in facts where fact.isOptional && !corpusKeys.contains(fact.wireKey) {
                violations.append("\(model).\(fact.name) is a phantom: wire key '\(fact.wireKey)' never arrives, the value is permanently nil")
            }
        }
        let decoder = FeedbackKitClient.decoder
        census("SDKUserResponse",
               storedProperties(of: try decoder.decode([SDKUserResponse].self, from: Fixtures.data("sdk-user-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "sdk-user-wire-corpus"))
        census("ViewEventResponse",
               storedProperties(of: try decoder.decode([ViewEventResponse].self, from: Fixtures.data("event-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "event-wire-corpus"))

        // METRICS03 phase 07 — the metrics models, censused against the key
        // UNION across every corpus row (see `Fixtures.metricsMetaKeyUnion`).
        let summary = try decoder.decode(MetricSummary.self, from: Fixtures.metricsRow("summary_team_all_scope"))
        let series = try decoder.decode(MetricSeries.self, from: Fixtures.metricsRow("timeseries_daily"))
        let breakdown = try decoder.decode(MetricBreakdown.self, from: Fixtures.metricsRow("breakdown_event_name_with_overflow"))
        let events = try decoder.decode(MetricEventList.self, from: Fixtures.metricsRow("events_page"))
        census("MetricsMeta", storedProperties(of: summary.meta), try Fixtures.metricsMetaKeyUnion())
        census("MetricSeriesPoint",
               storedProperties(of: try #require(series.series.first)),
               try Fixtures.metricsArrayKeyUnion("series", ofRow: "timeseries_daily"))
        census("MetricBreakdownItem",
               storedProperties(of: try #require(breakdown.items.first)),
               try Fixtures.metricsArrayKeyUnion("items", ofRow: "breakdown_event_name_with_overflow"))
        census("MetricPaginationMeta",
               storedProperties(of: events.meta),
               try Fixtures.metricsObjectKeys("meta", ofRow: "events_page"))
        #expect(violations.isEmpty, "\(violations)")
    }

    // MARK: - -11: unmodelled-key census (the reverse direction) — every key the
    // corpus carries binds to a property, or sits on an explicit allowlist.

    @Test func unmodelledKeyCensus() throws {
        // Deliberate omissions, reviewed: `unknown_future_key` is QA-UNIT10 -03's
        // adversarial extra-key row and MUST stay unmodelled for -27 to mean
        // anything. (`sync_states` and the hubspot_*/salesforce_* keys the spec
        // allowlists do not appear in the shipped corpus arm.)
        let allowlist: Set<String> = ["unknown_future_key"]
        var violations: [String] = []
        let decoder = FeedbackKitClient.decoder

        func census(_ model: String, _ facts: [PropertyFact], _ corpusKeys: Set<String>) {
            let bound = Set(facts.map(\.wireKey))
            for key in corpusKeys.subtracting(bound).subtracting(allowlist) {
                violations.append("\(model): corpus key '\(key)' binds to no property and is not allowlisted")
            }
        }
        census("VoteResponse",
               storedProperties(of: try decoder.decode([VoteResponse].self, from: Fixtures.data("vote-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "vote-wire-corpus"))
        census("SDKUserResponse",
               storedProperties(of: try decoder.decode([SDKUserResponse].self, from: Fixtures.data("sdk-user-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "sdk-user-wire-corpus"))
        census("ViewEventResponse",
               storedProperties(of: try decoder.decode([ViewEventResponse].self, from: Fixtures.data("event-wire-corpus"))[0]),
               try Fixtures.keyUnion(ofArrayCorpus: "event-wire-corpus"))
        census("FeedbackResponse",
               storedProperties(of: try decoder.decode(FeedbackResponse.self, from: Fixtures.row(0, ofArrayCorpus: "feedback-tolerance-corpus"))),
               try Fixtures.keyUnion(ofArrayCorpus: "feedback-tolerance-corpus"))

        // METRICS03 phase 07 — the metrics models, censused against the key
        // UNION across every corpus row (see `Fixtures.metricsMetaKeyUnion`).
        let summary = try decoder.decode(MetricSummary.self, from: Fixtures.metricsRow("summary_team_all_scope"))
        let series = try decoder.decode(MetricSeries.self, from: Fixtures.metricsRow("timeseries_daily"))
        let breakdown = try decoder.decode(MetricBreakdown.self, from: Fixtures.metricsRow("breakdown_event_name_with_overflow"))
        let events = try decoder.decode(MetricEventList.self, from: Fixtures.metricsRow("events_page"))
        census("MetricsMeta", storedProperties(of: summary.meta), try Fixtures.metricsMetaKeyUnion())
        census("MetricSeriesPoint",
               storedProperties(of: try #require(series.series.first)),
               try Fixtures.metricsArrayKeyUnion("series", ofRow: "timeseries_daily"))
        census("MetricBreakdownItem",
               storedProperties(of: try #require(breakdown.items.first)),
               try Fixtures.metricsArrayKeyUnion("items", ofRow: "breakdown_event_name_with_overflow"))
        census("MetricPaginationMeta",
               storedProperties(of: events.meta),
               try Fixtures.metricsObjectKeys("meta", ofRow: "events_page"))
        #expect(violations.isEmpty, "\(violations)")
    }

    // MARK: - -12: the acronym non-inverse rule — was RED ON ARRIVAL (F1 + F2),
    // fixed 2026-08-15 by renaming the four properties to the spelling the
    // strategy actually produces (`totalMrr` / `usersWithMrr` / `averageMrr` /
    // `slackWebhookUrl` — the spelling the Admin app's SDKUserModels and this
    // package's own `FeedbackResponse.totalMrr` already used).
    //
    // `.convertToSnakeCase` and `.convertFromSnakeCase` are not inverses for a
    // property name carrying a 2+ letter uppercase run. This is the only census
    // that sees a property no corpus row exercises — it works from the name
    // alone, over every model in the SDK. Note an explicit `CodingKeys` could
    // have made the decode work (spelled `= "totalMrr"`, the post-strategy key
    // — NEVER `= "total_mrr"`, which the strategy rewrites away first) but the
    // rename is the fix this census can see, and the one consistent with the
    // rest of the model surface.

    @Test func acronymNonInverseCensus() throws {
        let propertyPattern = try NSRegularExpression(pattern: #"public (?:let|var) ([A-Za-z_][A-Za-z0-9_]*)\s*:"#)
        var violations: [String] = []
        for file in try PackagePaths.swiftFiles(under: PackagePaths.modelsDir) {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in propertyPattern.matches(in: text, range: range) {
                guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
                let name = String(text[nameRange])
                let roundTripped = fromSnakeCase(toSnakeCase(name))
                if roundTripped != name {
                    violations.append("\(file.lastPathComponent): \(name) → wire '\(toSnakeCase(name))' → decodes to '\(roundTripped)', never '\(name)'")
                }
            }
        }
        #expect(violations.isEmpty, """
            Non-invertible property names — the server emits the snake_case key, \
            the SDK's decoder resolves it to a different camelCase spelling, so the \
            property can never bind: \(violations)
            """)
    }

    // MARK: - The F1 fix's value-level oracle. The -12 census above is a
    // name-shape census; this asserts the renamed `SDKUsersStats` actually
    // BINDS VALUES from the wire keys (`total_mrr`, `users_with_mrr`,
    // `average_mrr` — fix record 2026-08-15). No corpus arm exists for this
    // model (routed to QA-UNIT10), so the bytes come from the product's OWN
    // encoder — the same snake_case strategy the server uses, never a
    // hand-written literal (§4.5) — and the wire keys are asserted explicitly
    // so the round trip cannot be vacuously self-consistent. Under the shipped
    // `totalMRR` spellings this exact decode threw keyNotFound.

    @Test func statsDecodeBindsTheSnakeCaseWireKeys() throws {
        let stats = SDKUsersStats(totalUsers: 3, totalMrr: 129.5, usersWithMrr: 2, averageMrr: 64.75)
        let wire = try FeedbackKitClient.encoder.encode(stats)

        let object = try #require(JSONSerialization.jsonObject(with: wire) as? [String: Any])
        #expect(Set(object.keys)
            == ["total_users", "total_mrr", "users_with_mrr", "average_mrr"],
            "the encoded bytes must carry the server's snake_case wire keys")

        let decoded = try FeedbackKitClient.decoder.decode(SDKUsersStats.self, from: wire)
        #expect(decoded.totalUsers == 3)
        #expect(decoded.totalMrr == 129.5)
        #expect(decoded.usersWithMrr == 2)
        #expect(decoded.averageMrr == 64.75)

        // F2's half of the key agreement: the Slack webhook key crosses the
        // wire as `slack_webhook_url`, which the decode strategy resolves to
        // exactly the renamed `ProjectResponse.slackWebhookUrl` spelling.
        // (ProjectResponse itself has no corpus and ~43 required keys, so the
        // full-object decode stays blocked on a QA-UNIT10 corpus arm; the -12
        // census above is F2's shipped pin.)
        #expect(fromSnakeCase("slack_webhook_url") == "slackWebhookUrl")
    }
}
