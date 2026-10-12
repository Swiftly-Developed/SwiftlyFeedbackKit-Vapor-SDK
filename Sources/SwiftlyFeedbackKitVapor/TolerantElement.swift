import Vapor

/// The list-decode tolerance contract (AGENTS.md; the QA-UNIT10 Flutter shape):
/// a list element whose strict server-fed enum carries a token this SDK version
/// does not know decodes to `nil` and is dropped by the call site's
/// `compactMap(\.value)` — every other row survives in order. A genuinely
/// malformed row (missing required key, type mismatch on a known field) still
/// throws, because swallowing it would turn a decode regression into a silently
/// short list.
///
/// An unknown raw value in a synthesized `RawRepresentable` decode throws
/// `DecodingError.dataCorrupted`, which is the only failure shape dropped here.
///
/// This is the single definition of the wrapper; `FeedbackAPI.list` routes
/// through it, and `VaporSDKParityTests` (-27) asserts both halves against the
/// server-generated tolerance corpus.
struct TolerantElement<Model: Content>: Content {
    let value: Model?

    init(from decoder: any Decoder) throws {
        do {
            value = try Model(from: decoder)
        } catch DecodingError.dataCorrupted {
            // Dropped: the row is from a newer server vocabulary.
            value = nil
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
