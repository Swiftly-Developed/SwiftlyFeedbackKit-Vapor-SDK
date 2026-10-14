import Foundation
import Testing
@testable import SwiftlyFeedbackKitVapor

/// QA-UNIT12 Part A — the target, and its place in the map.
@Suite("VaporSDK target and manifest gates")
struct VaporSDKTargetSuite {

    // -01: the manifest edit is exactly one `.testTarget`, and the package's
    // `dependencies:` array is unchanged — no new package dependency reaches a
    // published package.
    @Test func manifestDependencyNeutrality() throws {
        let manifest = try String(contentsOf: PackagePaths.manifest, encoding: .utf8)

        let packageDeclarations = manifest.components(separatedBy: ".package(url:").count - 1
        #expect(packageDeclarations == 1, "the published manifest must declare exactly one package dependency (vapor)")
        #expect(manifest.contains("https://github.com/vapor/vapor.git"))

        let testTargets = manifest.components(separatedBy: ".testTarget(").count - 1
        #expect(testTargets == 1, "exactly one .testTarget")
        #expect(manifest.contains("name: \"SwiftlyFeedbackKitVaporTests\""))

        // The rejected options must stay rejected (QA-UNIT12 §14.2): each of these
        // would put a test-only dependency into a *published* manifest.
        #expect(!manifest.contains("XCTVapor"))
        #expect(!manifest.contains("VaporTesting"))
        #expect(!manifest.contains("swift-nio.git"))
        #expect(!manifest.contains("fluent"))
    }

    // -02: the declared test target has backing sources (the 1.1.1 regression:
    // a `.testTarget` with no `Tests/` directory). `swift build --build-tests`
    // is the real gate; this asserts the directory contract it depends on.
    @Test func testTargetHasBackingSources() throws {
        let files = try PackagePaths.swiftFiles(under: PackagePaths.testsDir)
        #expect(!files.isEmpty, "a .testTarget with no backing sources is the exact 1.1.1 regression")
    }

    // -03 (in-package half): the filter token. Every `@Suite` type in this target
    // must be scopeable by the single token `VaporSDK`, so the lane's invocation
    // can filter it. The L1-CLASSIFICATION.md invocation-table row is phase 08's.
    @Test func everySuiteTypeMatchesTheFilterToken() throws {
        let files = try PackagePaths.swiftFiles(under: PackagePaths.testsDir)
        let declPattern = try NSRegularExpression(pattern: #"struct\s+([A-Za-z0-9_]+)\s*\{?"#)
        var offenders: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            // Only types carrying @Suite matter for filtering.
            let lines = text.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("@Suite") {
                // The declaration is on this line or the next.
                let window = line + "\n" + (index + 1 < lines.count ? lines[index + 1] : "")
                let range = NSRange(window.startIndex..., in: window)
                if let match = declPattern.firstMatch(in: window, range: range),
                   let nameRange = Range(match.range(at: 1), in: window) {
                    let name = String(window[nameRange])
                    if !name.hasPrefix("VaporSDK") { offenders.append(name) }
                }
            }
        }
        #expect(offenders.isEmpty, "suite types not matching the 'VaporSDK' filter token: \(offenders)")
    }

    // -04 (structural half): the resolved graph contains no database driver and
    // the package declares exactly one dependency. The runtime half — the whole
    // target green with PostgreSQL stopped and DATABASE_NAME unset — is a
    // property of the invocation, proved by every run of this suite.
    @Test func noDatabaseDriverInTheGraph() throws {
        let resolvedURL = PackagePaths.packageRoot.appendingPathComponent("Package.resolved")
        let resolved = try String(contentsOf: resolvedURL, encoding: .utf8).lowercased()
        for banned in ["fluent", "postgres", "sqlite-kit", "mysql", "mongo", "redis"] {
            #expect(!resolved.contains(banned), "database driver '\(banned)' appeared in the resolved graph")
        }
    }
}

/// QA-UNIT12 Part B (structural) and -29 — fixture discipline and the no-duplication guard.
@Suite("VaporSDK fixture discipline")
struct VaporSDKFixtureDisciplineSuite {

    // -05 (in-target half): every committed fixture parses and is in canonical
    // generated form (sorted keys, pretty-printed). The byte-level
    // regenerate-and-diff provenance gate lives with the corpus generator in the
    // server tree (QA-UNIT10 -01), which cannot run from this package.
    @Test func fixturesAreCanonicalGeneratedForm() throws {
        for name in Fixtures.names {
            let data = try Fixtures.data(name)
            let object = try JSONSerialization.jsonObject(with: data)
            let canonical = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            let committed = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let regenerated = String(decoding: canonical, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(committed == regenerated, "\(name).json is not in canonical generated form — it has been hand-edited")
        }
    }

    // -05 (completeness half): `Fixtures.names` is what
    // `fixturesAreCanonicalGeneratedForm` iterates, so a corpus sitting in the
    // directory but missing from the list is UNGATED. The count is derived by
    // enumerating the directory — a hardcoded number cannot see the next
    // corpus a later phase drops in and forgets to list.
    @Test func fixtureNamesCoverTheWholeFixturesDirectory() throws {
        let onDisk = Set(
            (FileManager.default.enumerator(at: PackagePaths.fixturesDir, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL } ?? [])
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )
        #expect(!onDisk.isEmpty, "no .json found under Fixtures/ — the enumerator read nothing")
        let listed = Set(Fixtures.names)
        #expect(listed == onDisk,
                "on disk but unlisted (and therefore ungated): \(onDisk.subtracting(listed).sorted()); listed but absent: \(listed.subtracting(onDisk).sorted())")
        #expect(Fixtures.names.count == onDisk.count, "Fixtures.names has a duplicate")
    }

    // -06: no hand-written JSON literal reaches a decoder outside Fixtures/.
    // The three sibling SDKs that broke this rule were each "careful"
    // (QA-UNIT12 §4.5) — so the rule is enforced by a scan, not by intent.
    @Test func noHandWrittenJSONLiteralUnderTests() throws {
        // Patterns assembled from escapes so this file cannot match itself.
        let escapedQuoteColon = "\u{5C}" + "\u{22}" + ":"          // backslash, quote, colon — an inline JSON literal
        let jsonObjectLine = try NSRegularExpression(
            pattern: "^\\s*" + "\u{22}" + "[A-Za-z0-9_]+" + "\u{22}" + "\\s*:"
        ) // a `"key":` line inside a multiline string literal
        var offenders: [String] = []
        // The paired positive: "green" means "scanned and clean", never "not
        // scanned". The denominator moves whenever a file joins the target —
        // METRICS03 phase 07 took it from 12 to 13, the Linux JSON number
        // helper plus its test took it from 13 to 15, the wire-contract
        // suite took it from 15 to 16, and REL-05's live list suite took it
        // from 16 to 17.
        let files = try PackagePaths.swiftFiles(under: PackagePaths.testsDir)
        #expect(files.count == 17, "scanned \(files.count) files under Tests/ — the denominator moved")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            if text.contains(escapedQuoteColon) {
                offenders.append("\(file.lastPathComponent): inline JSON string literal")
            }
            for line in text.components(separatedBy: "\n") {
                let range = NSRange(line.startIndex..., in: line)
                if jsonObjectLine.firstMatch(in: line, range: range) != nil {
                    offenders.append("\(file.lastPathComponent): JSON-shaped line in a string literal")
                    break
                }
            }
        }
        #expect(offenders.isEmpty, "hand-written JSON found under Tests/: \(offenders)")
    }

    // -07 (present kinds): the adversarial row kinds the shipped corpus carries.
    // The kinds it does NOT carry (explicit-null rows, one row per uppercase-run
    // property, and any Project/Comment/Stats corpus at all) are QA-UNIT10 corpus
    // gaps recorded in this suite's report — a missing corpus blocks an ID, it
    // does not license a literal (QA-UNIT12 §9.6).
    @Test func toleranceCorpusCarriesItsAdversarialRows() throws {
        let any = try JSONSerialization.jsonObject(with: Fixtures.data("feedback-tolerance-corpus"))
        let rows = try #require(any as? [[String: Any]])

        let knownStatuses = Set(FeedbackStatus.allCases.map(\.rawValue))
        let statuses = rows.compactMap { $0["status"] as? String }
        #expect(statuses.contains { !knownStatuses.contains($0) }, "corpus must carry an unknown enum token row")
        #expect(statuses.filter { !knownStatuses.contains($0) }.count == 1, "exactly one unknown-status row, so -27 can assert order")

        #expect(rows.contains { $0.keys.contains("unknown_future_key") }, "corpus must carry an unknown extra key row")

        let userRows = try #require(try JSONSerialization.jsonObject(with: Fixtures.data("sdk-user-wire-corpus")) as? [[String: Any]])
        #expect(userRows.contains { !$0.keys.contains("mrr") }, "corpus must carry an absent-optional-key row")

        let voteRows = try #require(try JSONSerialization.jsonObject(with: Fixtures.data("vote-wire-corpus")) as? [[String: Any]])
        #expect(voteRows.contains { ($0["has_voted"] as? Bool) == true }, "corpus must carry at least one true boolean")
    }

    // -29: no duplication of QA-UNIT10 — no second corpus, no cross-SDK
    // comparison, no reference to another SDK's tree under Tests/.
    @Test func noCrossSDKReferenceAndNoSecondCorpus() throws {
        // Assembled by concatenation so this file cannot match itself.
        let prefix = "SwiftlyFeedbackKit" + "-"
        let foreignTrees = ["JS", "RN", "Flutter", "Kotlin"].map { prefix + $0 } + ["SwiftlyFeedback" + "Server"]
        let escape = ".." + "/" + ".."
        var offenders: [String] = []
        let selfName = "VaporSDKTargetTests.swift"
        for file in try PackagePaths.swiftFiles(under: PackagePaths.testsDir) where file.lastPathComponent != selfName {
            let text = try String(contentsOf: file, encoding: .utf8)
            for needle in foreignTrees where text.contains(needle) {
                offenders.append("\(file.lastPathComponent) references \(needle)")
            }
            if text.contains(escape) {
                offenders.append("\(file.lastPathComponent) escapes the package root")
            }
        }
        // No .json exists outside Fixtures/ (a second corpus is two definitions of one contract).
        let allFiles = FileManager.default.enumerator(at: PackagePaths.testsDir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        for file in allFiles where file.pathExtension == "json" {
            if !file.path.contains("/Fixtures/") {
                offenders.append("stray corpus file \(file.lastPathComponent)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }
}
