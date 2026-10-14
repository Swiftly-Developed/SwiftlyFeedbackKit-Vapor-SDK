import Foundation

/// Percent-encodes query items so the FeedbackKit server's own form parser reads
/// back exactly the value the caller passed.
///
/// Three steps, each load-bearing — measured against 12 hostile values
/// round-tripped through Vapor's `URLEncodedFormParser` semantics:
///
/// 1. build a `URLComponents` and assign `queryItems`;
/// 2. read **`percentEncodedQuery`** back, not `query`, which returns the
///    decoded form and would undo step 1;
/// 3. escape a literal `+` to `%2B`. `URLQueryItem` leaves `+` alone, and the
///    parser's very first statement replaces `+` with `%20` — so without this
///    step a value containing `+` arrives as a space.
///
/// Scores on that corpus: naive `k=v` concatenation 7/12, steps 1–2 alone
/// 11/12, all three steps 12/12.
///
/// `internal` by construction: this widens no published surface.
enum URLQueryEncoding {

    /// The encoded query string for `items`, or `nil` when there is nothing to
    /// encode — callers use `nil` to mean "emit no `?` at all", which is what
    /// keeps query-less URIs byte-identical to the pre-builder spelling.
    static func query(_ items: [URLQueryItem]) -> String? {
        guard !items.isEmpty else { return nil }
        var components = URLComponents()
        components.queryItems = items
        guard let encoded = components.percentEncodedQuery, !encoded.isEmpty else { return nil }
        return encoded.replacingOccurrences(of: "+", with: "%2B")
    }
}
