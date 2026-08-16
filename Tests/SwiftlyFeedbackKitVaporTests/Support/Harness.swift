import Foundation
import Vapor
@testable import SwiftlyFeedbackKitVapor

// MARK: - Fixed synthetic values (no live credential anywhere — QA-UNIT12 §9.8)

enum Fixed {
    static let apiKey = "test-api-key-fixture"
    static let bearerToken = "test-bearer-token-fixture"
    static let baseURL = URL(string: "https://stub.example")!
    static let apiBase = "https://stub.example/api/v1"
    /// Valid-hex UUID mnemonics (AGENTS.md: mnemonic letter prefixes must be hex).
    static let idA = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
    static let idB = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!
}

// MARK: - Product construction through the seam (QA-UNIT12 -13)

func makeStubbedClient(
    stub: StubClient,
    apiKey: String = Fixed.apiKey,
    environment: FeedbackKitEnvironment = .custom(Fixed.baseURL)
) -> FeedbackKitClient {
    // The synthesised internal memberwise init IS the seam. If this stops
    // compiling, an explicit init or a `private` stored property has removed it
    // — re-decide QA-UNIT12 §14.2 before "fixing" the test.
    FeedbackKitClient(
        client: stub,
        configuration: FeedbackKitConfiguration(apiKey: apiKey, environment: environment),
        logger: Logger(label: "vapor-sdk-tests")
    )
}

func makeSDK(stub: StubClient, environment: FeedbackKitEnvironment = .custom(Fixed.baseURL)) -> FeedbackKitSDK {
    FeedbackKitSDK(client: makeStubbedClient(stub: stub, environment: environment))
}

func makeAdmin(stub: StubClient, token: String = Fixed.bearerToken) -> FeedbackKitAdmin {
    FeedbackKitAdmin(client: makeStubbedClient(stub: stub), token: token)
}

// MARK: - Fixtures (the Vapor arm of QA-UNIT10 -01's corpus; never hand-edited)

enum Fixtures {
    static let names = [
        "event-wire-corpus",
        "feedback-tolerance-corpus",
        "request-wire-corpus",
        "sdk-user-wire-corpus",
        "vote-wire-corpus",
    ]

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    /// The union of object keys across every row of an array-of-objects corpus.
    static func keyUnion(ofArrayCorpus name: String) throws -> Set<String> {
        let any = try JSONSerialization.jsonObject(with: data(name))
        guard let rows = any as? [[String: Any]] else { throw FixtureError.shape(name) }
        return rows.reduce(into: Set<String>()) { $0.formUnion($1.keys) }
    }

    /// The keys of one named request-shape in the request-wire corpus.
    static func requestKeys(_ shape: String) throws -> Set<String> {
        let any = try JSONSerialization.jsonObject(with: data("request-wire-corpus"))
        guard let byShape = any as? [String: [String: Any]], let object = byShape[shape] else {
            throw FixtureError.shape("request-wire-corpus/\(shape)")
        }
        return Set(object.keys)
    }

    /// One row of an array corpus, re-serialized as standalone bytes.
    /// Derived from the corpus — this is row *extraction*, not fixture authorship.
    static func row(_ index: Int, ofArrayCorpus name: String) throws -> Data {
        let any = try JSONSerialization.jsonObject(with: data(name))
        guard let rows = any as? [[String: Any]], rows.indices.contains(index) else {
            throw FixtureError.shape(name)
        }
        return try JSONSerialization.data(withJSONObject: rows[index], options: [.sortedKeys])
    }

    /// The array corpus with one key removed from one row — for building a
    /// *genuinely malformed* row out of corpus material (QA-UNIT12 -27's second half).
    static func arrayCorpus(_ name: String, removingKey key: String, fromRow index: Int) throws -> Data {
        let any = try JSONSerialization.jsonObject(with: data(name))
        guard var rows = any as? [[String: Any]], rows.indices.contains(index) else {
            throw FixtureError.shape(name)
        }
        rows[index].removeValue(forKey: key)
        return try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
    }

    enum FixtureError: Error {
        case missing(String)
        case shape(String)
    }
}

// MARK: - Package paths (for structural source scans)

enum PackagePaths {
    /// `…/SwiftlyFeedbackKit-Vapor` — derived from this file's own location, so the
    /// scans never leave the package (QA-UNIT12 -29).
    static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // SwiftlyFeedbackKitVaporTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // package root

    static let manifest = packageRoot.appendingPathComponent("Package.swift")
    static let sourcesDir = packageRoot.appendingPathComponent("Sources/SwiftlyFeedbackKitVapor")
    static let modelsDir = sourcesDir.appendingPathComponent("Models")
    static let apiDir = sourcesDir.appendingPathComponent("API")
    static let testsDir = packageRoot.appendingPathComponent("Tests/SwiftlyFeedbackKitVaporTests")
    static let fixturesDir = testsDir.appendingPathComponent("Fixtures")

    static func swiftFiles(under dir: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }
}

// MARK: - Snake-case derivations (replicas of Foundation's strategies, for QA-UNIT12 -09…-12)

/// Replica of `JSONEncoder.KeyEncodingStrategy.convertToSnakeCase`.
func toSnakeCase(_ name: String) -> String {
    guard !name.isEmpty else { return name }
    var words: [Range<String.Index>] = []
    var wordStart = name.startIndex
    var searchRange = name.index(after: wordStart)..<name.endIndex

    while let upperCaseRange = name.rangeOfCharacter(from: .uppercaseLetters, options: [], range: searchRange) {
        let untilUpperCase = wordStart..<upperCaseRange.lowerBound
        words.append(untilUpperCase)

        searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
        guard let lowerCaseRange = name.rangeOfCharacter(from: .lowercaseLetters, options: [], range: searchRange) else {
            wordStart = searchRange.lowerBound
            break
        }

        let nextCharacterAfterCapital = name.index(after: upperCaseRange.lowerBound)
        if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
            wordStart = upperCaseRange.lowerBound
        } else {
            let beforeLowerIndex = name.index(before: lowerCaseRange.lowerBound)
            words.append(upperCaseRange.lowerBound..<beforeLowerIndex)
            wordStart = beforeLowerIndex
        }
        searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
    }
    words.append(wordStart..<searchRange.upperBound)
    return words.map { name[$0].lowercased() }.joined(separator: "_")
}

/// Replica of `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase`.
func fromSnakeCase(_ key: String) -> String {
    guard !key.isEmpty else { return key }
    let components = key.split(separator: "_")
    guard components.count > 1 else { return key }
    return ([components[0].lowercased()] + components[1...].map { $0.capitalized }).joined()
}

// MARK: - Property census via Mirror (QA-UNIT12 -09/-10/-11)

struct PropertyFact: Sendable, Hashable {
    let name: String
    let isOptional: Bool
    var wireKey: String { toSnakeCase(name) }
}

/// Stored-property census of a value. `Mirror` reflects stored properties only,
/// so computed conveniences (`isMerged`, …) never enter the census.
func storedProperties(of value: Any) -> [PropertyFact] {
    Mirror(reflecting: value).children.compactMap { child in
        guard let label = child.label else { return nil }
        let isOptional = Mirror(reflecting: child.value).displayStyle == .optional
        return PropertyFact(name: label, isOptional: isOptional)
    }
}

// MARK: - Error-case discrimination (FeedbackKitError is not Equatable)

func caseName(_ error: FeedbackKitError) -> String {
    switch error {
    case .badRequest: "badRequest"
    case .unauthorized: "unauthorized"
    case .invalidApiKey: "invalidApiKey"
    case .paymentRequired: "paymentRequired"
    case .forbidden: "forbidden"
    case .notFound: "notFound"
    case .conflict: "conflict"
    case .serverError: "serverError"
    case .decodingError: "decodingError"
    case .notConfigured: "notConfigured"
    case .operationNotSupported: "operationNotSupported"
    }
}

/// The server's error envelope, encoded from the product's own internal DTO
/// through the product's own encoder — never a hand-written JSON literal
/// (QA-UNIT12 §4.5, -06).
func errorEnvelope(reason: String?) throws -> Data {
    try FeedbackKitClient.encoder.encode(ErrorMessageDTO(error: true, reason: reason))
}
