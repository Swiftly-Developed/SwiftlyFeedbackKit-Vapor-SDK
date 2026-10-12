import Vapor

// MARK: - Meta

/// The `meta` block every metrics response carries — nine fields, of which
/// ``granularity`` is the only optional one.
///
/// `granularity` is **omitted** from a `summary` response and from an event
/// feed page; it is never sent as JSON `null`. It is present on `timeseries`
/// and — less obviously — on `breakdown`, where the server resolves it to
/// `day` by default and echoes it back even though it buckets nothing there.
/// A host that reads its presence as "this is a timeseries" is wrong.
///
/// No `CodingKeys` anywhere in this file: the client's global
/// `.convertFromSnakeCase` strategy maps the wire keys centrally, exactly as
/// `Dashboard.swift` and `ViewEvent.swift` rely on. Adding an explicit key map
/// here changes which spelling the strategy sees.
public struct MetricsMeta: Content, Sendable {
    /// The resolved measure list, in first-seen order. The server's snake_case
    /// measure tokens — the same strings that key ``MetricSummary/values``.
    public let measures: [String]
    /// The resolved bucket width, as a wire token (`hour` / `day` / `week` /
    /// `month`). Absent on `summary` and on the event feed.
    public let granularity: String?
    /// The reporting zone actually applied.
    public let timezone: String
    /// ISO-8601 instant — the **inclusive** first day of the window.
    public let dateFrom: String
    /// ISO-8601 instant — the **inclusive** last day. Never the exclusive end.
    public let dateTo: String
    /// True only when a breakdown's cardinality ceiling elided names.
    public let truncated: Bool
    /// `all` or `predefined_only`. A `predefined_only` response is a **success**
    /// carrying a narrower answer, not an error.
    public let eventScope: String
    /// True when the plan narrowed the requested window.
    ///
    /// Deliberately **not idempotent**: re-requesting an already-clamped window
    /// returns the same window with this flag `false`, because the second
    /// request genuinely asks for something inside the allowance. Never derive
    /// the flag by comparing what you asked for against what came back.
    public let retentionClamped: Bool
    /// The plan's window allowance in days (Free 30, Pro 90, Team 365).
    /// Read this — never hardcode 30, 90, or 365.
    public let retentionWindowDays: Int
}

public extension MetricsMeta {
    /// ``dateFrom`` parsed, or `nil` when the server sent a spelling this
    /// parser does not recognise. The raw string stays available so a host can
    /// echo back the exact bytes the server sent.
    var parsedDateFrom: Date? { metricsParseInstant(dateFrom) }

    /// ``dateTo`` parsed. See ``parsedDateFrom``.
    var parsedDateTo: Date? { metricsParseInstant(dateTo) }

    /// ``granularity`` resolved against the closed vocabulary, or `nil` when
    /// absent (summary, event feed) or unrecognised.
    var resolvedGranularity: MetricGranularity? { granularity.flatMap(MetricGranularity.init(rawValue:)) }

    /// ``eventScope`` resolved against the closed vocabulary.
    var resolvedEventScope: MetricEventScope? { MetricEventScope(rawValue: eventScope) }
}

/// Parses the date spellings the metrics surface speaks: an ISO-8601 instant
/// with or without fractional seconds, and a bare `yyyy-MM-dd` a caller may
/// send on the request side. `internal`, not public — the published surface
/// stays the two accessors above, and `MetricsQuery` uses it to refuse an
/// inverted window before the round trip.
///
/// Returns `nil` for anything else, which callers must treat as "let the
/// server decide" rather than as "invalid".
func metricsParseInstant(_ value: String) -> Date? {
    let plain = ISO8601DateFormatter()
    if let date = plain.date(from: value) { return date }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    let dateOnly = ISO8601DateFormatter()
    dateOnly.formatOptions = [.withFullDate]
    return dateOnly.date(from: value)
}

// MARK: - Responses

/// `GET …/metrics/summary` — one number per measure over the whole window.
public struct MetricSummary: Content, Sendable {
    public let meta: MetricsMeta
    /// Measure token → value. **Sparse by design**; read it through the
    /// ``subscript(_:)`` below rather than force-unwrapping.
    public let values: [String: Double]
}

/// One bucket of a timeseries.
///
/// Exactly two fields. There is **no** `bucket_start`: the server sends one
/// bucket label and its values, and a model declaring a second date field
/// would bind nothing.
public struct MetricSeriesPoint: Content, Sendable {
    /// The bucket label, as the server formatted it for the reporting zone.
    public let bucket: String
    public let values: [String: Double]
}

/// `GET …/metrics/timeseries`.
///
/// Empty buckets are **present and zero-valued**, not omitted — an `isEmpty`
/// branch on ``series`` never fires for a quiet window, so handle the all-zero
/// case explicitly.
public struct MetricSeries: Content, Sendable {
    public let meta: MetricsMeta
    public let series: [MetricSeriesPoint]
}

/// One row of a breakdown.
public struct MetricBreakdownItem: Content, Sendable {
    /// The dimension value this row aggregates.
    public let key: String
    public let values: [String: Double]
    /// True on the single synthetic row collecting everything the cardinality
    /// ceiling elided. That row omits `unique_event_users` entirely — a
    /// distinct-user count is not additive across elided names — which is why
    /// every measure accessor in this file returns an optional.
    public let isOverflow: Bool
}

/// `GET …/metrics/breakdown`. Items are ordered by the first measure, descending.
public struct MetricBreakdown: Content, Sendable {
    public let meta: MetricsMeta
    /// The dimension the server resolved, as a wire token.
    public let dimension: String
    public let items: [MetricBreakdownItem]
}

/// The event feed's pagination block — the `meta` key on that response only.
public struct MetricPaginationMeta: Content, Sendable {
    public let total: Int
    public let page: Int
    public let perPage: Int
    public let totalPages: Int
}

/// `GET …/metrics/events` — the raw event feed.
///
/// This response carries **two** meta blocks: ``meta`` is pagination and
/// ``metrics`` is the ``MetricsMeta`` of every other metrics response. A model
/// that puts the metrics block under `meta` here decodes nothing.
///
/// ``items`` reuses ``ViewEventResponse``, the same row type the tracking API
/// returns — the two wire corpora carry structurally identical rows on
/// purpose. Changing ``ViewEventResponse`` therefore moves this feed too.
public struct MetricEventList: Content, Sendable {
    public let items: [ViewEventResponse]
    public let meta: MetricPaginationMeta
    public let metrics: MetricsMeta
}

// MARK: - Typed measure access

public extension MetricSummary {
    /// The value for `measure`, or `nil` when the response does not carry it.
    subscript(_ measure: MetricMeasure) -> Double? { values[measure.rawValue] }
}

public extension MetricSeriesPoint {
    /// The value for `measure`, or `nil` when this bucket does not carry it.
    subscript(_ measure: MetricMeasure) -> Double? { values[measure.rawValue] }
}

public extension MetricBreakdownItem {
    /// The value for `measure`, or `nil` when this row does not carry it —
    /// which the overflow row does for `unique_event_users`, in production.
    subscript(_ measure: MetricMeasure) -> Double? { values[measure.rawValue] }
}

// MARK: - Closed vocabularies

/// The nine measures the metrics surface aggregates. Raw values are the wire
/// tokens, and the same strings key every `values` dictionary.
public enum MetricMeasure: String, Content, CaseIterable, Sendable {
    case feedbackCount = "feedback_count"
    case voteCount = "vote_count"
    case commentCount = "comment_count"
    case eventCount = "event_count"
    case uniqueEventUsers = "unique_event_users"
    case sdkUserCount = "sdk_user_count"
    case mrrSum = "mrr_sum"
    case mrrAverage = "mrr_average"
    case usersWithMrr = "users_with_mrr"
}

public extension MetricMeasure {
    /// Whether the X-API-Key surface serves this measure. **Descriptive only**
    /// — the server owns the boundary, and this SDK deliberately does not
    /// pre-reject: request a Bearer-only measure through ``MetricsAPI`` and the
    /// server answers a typed 403, surfacing as
    /// ``FeedbackKitError/measureNotAvailable(measure:message:)``.
    ///
    /// Spelled `ApiKey`, not `APIKey`: the two snake-case strategies are not
    /// inverses across a 2+ letter uppercase run, and the package's naming
    /// census rejects the uppercase spelling for that reason.
    var isAvailableOnApiKey: Bool {
        switch self {
        case .feedbackCount, .voteCount, .commentCount, .eventCount, .uniqueEventUsers:
            true
        case .sdkUserCount, .mrrSum, .mrrAverage, .usersWithMrr:
            false
        }
    }
}

/// Timeseries bucket widths. The raw values are the **wire tokens** — the
/// server's own Swift case names (`hourly`, `daily`, …) are not.
public enum MetricGranularity: String, Content, CaseIterable, Sendable {
    case hour
    case day
    case week
    case month
}

/// The dimensions a breakdown may group by.
public enum MetricDimension: String, Content, CaseIterable, Sendable {
    case status
    case category
    case eventName = "event_name"
}

/// How wide a scope the answer covers. `predefinedOnly` is what a Free-plan
/// project receives: a **success** carrying a narrower answer, never an error.
public enum MetricEventScope: String, Content, CaseIterable, Sendable {
    case all
    case predefinedOnly = "predefined_only"
}

/// FeedbackKit's own three reserved event names. **Exact and case-sensitive**:
/// an event tracked under a differing case is a *custom* event and lands
/// behind the Pro gate.
public enum PredefinedEventName: String, Content, CaseIterable, Sendable {
    case feedbackList = "feedback_list"
    case feedbackDetail = "feedback_detail"
    case submitFeedback = "submit_feedback"
}
