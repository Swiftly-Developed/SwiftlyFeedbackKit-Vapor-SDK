import Vapor

/// Every parameter the metrics surface reads, built once so the X-API-Key
/// family and the Bearer family cannot drift in spelling or in ordering.
///
/// The wire spellings are the server's, verbatim — snake_case keys, with
/// `measures`, `status` and `category` **comma-joined into a single
/// parameter** rather than repeated, and `event_name` a single free-form
/// value. Nothing here concatenates a URL: the items go to the client's
/// query-carrying verbs, which percent-encode through `URLQueryEncoding`.
///
/// `internal`: hosts build a query by calling an operation, not by
/// constructing this.
struct MetricsQuery: Sendable {
    var measures: [MetricMeasure] = []
    var granularity: MetricGranularity?
    var dimension: MetricDimension?
    var status: [FeedbackStatus] = []
    var category: [FeedbackCategory] = []
    var eventName: String?
    var dateFrom: String?
    var dateTo: String?
    var days: Int?
    var page: Int?
    var perPage: Int?

    /// The range the server accepts for `per_page`. Out of range it answers a
    /// **400**, never a silent clamp — the clamp below is a client-side
    /// fail-fast convenience, not a mirror of server behaviour.
    static let perPageRange = 1...200

    /// The query items, in the order the contract table lists them.
    ///
    /// Two requests are refused here rather than round-tripped, because each
    /// is a 400 the caller can avoid entirely and neither needs the server to
    /// diagnose: `days` together with an explicit window
    /// (`METRICS_CONFLICTING_WINDOW_PARAMS`), and a window whose start is
    /// after its end (`METRICS_INVALID_DATE_RANGE`). The inverted-window check
    /// runs only when **both** bounds parse — an unrecognised spelling is the
    /// server's `METRICS_INVALID_DATE` to raise, not this SDK's to guess at.
    func items() throws -> [URLQueryItem] {
        if days != nil, dateFrom != nil || dateTo != nil {
            throw FeedbackKitError.badRequest(
                message: "A metrics window is either a day count or an explicit date_from/date_to pair, never both."
            )
        }
        if let from = dateFrom.flatMap(metricsParseInstant),
           let to = dateTo.flatMap(metricsParseInstant),
           from > to {
            throw FeedbackKitError.badRequest(
                message: "The metrics window starts after it ends: date_from must not be later than date_to."
            )
        }

        var items: [URLQueryItem] = []
        items.append(URLQueryItem(name: "measures", value: measures.map(\.rawValue).joined(separator: ",")))
        if let granularity {
            items.append(URLQueryItem(name: "granularity", value: granularity.rawValue))
        }
        if let dimension {
            items.append(URLQueryItem(name: "dimension", value: dimension.rawValue))
        }
        if !status.isEmpty {
            items.append(URLQueryItem(name: "status", value: status.map(\.rawValue).joined(separator: ",")))
        }
        if !category.isEmpty {
            items.append(URLQueryItem(name: "category", value: category.map(\.rawValue).joined(separator: ",")))
        }
        if let eventName {
            items.append(URLQueryItem(name: "event_name", value: eventName))
        }
        if let dateFrom {
            items.append(URLQueryItem(name: "date_from", value: dateFrom))
        }
        if let dateTo {
            items.append(URLQueryItem(name: "date_to", value: dateTo))
        }
        if let days {
            items.append(URLQueryItem(name: "days", value: "\(days)"))
        }
        if let page {
            items.append(URLQueryItem(name: "page", value: "\(page)"))
        }
        if let perPage {
            let clamped = min(max(perPage, Self.perPageRange.lowerBound), Self.perPageRange.upperBound)
            items.append(URLQueryItem(name: "per_page", value: "\(clamped)"))
        }
        return items
    }
}
