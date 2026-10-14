import Vapor

/// Metrics reads on the **X-API-Key** surface.
///
/// The key identifies the project, so no operation here takes a project
/// identifier. Every call goes through the client's X-API-Key verb; the Bearer
/// twin is `AdminMetricsAPI`, and the two must never be crossed — a metrics
/// read issued with the wrong credential compiles, type-checks, and answers
/// 401 in production.
///
/// Two things this surface deliberately does **not** do:
///
/// - it does not pre-reject a measure. The four revenue and audience measures
///   are reachable from here and come back as a typed 403
///   (``FeedbackKitError/measureNotAvailable(measure:message:)``); the server
///   owns that boundary, in one place, for every SDK.
/// - it does not treat a narrowed answer as a failure. A Free-plan project
///   receives **200** with `event_scope` reading `predefined_only`, and a
///   window wider than the plan allows comes back clamped with
///   `retention_clamped` set — successes carrying less, not errors.
///
/// This family is rate-limited at 60 requests per 60 seconds; over budget the
/// server answers ``FeedbackKitError/rateLimited(message:)``.
public struct MetricsAPI: Sendable {
    let client: FeedbackKitClient

    /// Totals over the whole window — one number per measure.
    ///
    /// - Parameters:
    ///   - measures: Required, and sent as one comma-joined parameter.
    ///   - status: Restrict to these feedback statuses.
    ///   - category: Restrict to these feedback categories.
    ///   - eventName: Restrict to a single event name. Free-form and
    ///     percent-encoded; a name the plan does not cover is answered by the
    ///     tier gate, not by this SDK.
    ///   - dateFrom: Inclusive window start. Mutually exclusive with `days`.
    ///   - dateTo: Inclusive window end. Mutually exclusive with `days`.
    ///   - days: Window length in days, counting back from today.
    /// - Note: The response's `meta` carries no `granularity` on this
    ///   operation — the key is absent, not null.
    public func summary(
        measures: [MetricMeasure],
        status: [FeedbackStatus] = [],
        category: [FeedbackCategory] = [],
        eventName: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        days: Int? = nil
    ) async throws -> MetricSummary {
        let query = MetricsQuery(
            measures: measures, status: status, category: category, eventName: eventName,
            dateFrom: dateFrom, dateTo: dateTo, days: days
        )
        return try await client.get(path: "/metrics/summary", queryItems: try query.items())
    }

    /// One point per bucket across the window.
    ///
    /// Quiet buckets are **present and zero-valued**, so the series is never
    /// short and an emptiness check never fires for a quiet period.
    public func timeseries(
        measures: [MetricMeasure],
        granularity: MetricGranularity? = nil,
        status: [FeedbackStatus] = [],
        category: [FeedbackCategory] = [],
        eventName: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        days: Int? = nil
    ) async throws -> MetricSeries {
        let query = MetricsQuery(
            measures: measures, granularity: granularity, status: status, category: category,
            eventName: eventName, dateFrom: dateFrom, dateTo: dateTo, days: days
        )
        return try await client.get(path: "/metrics/timeseries", queryItems: try query.items())
    }

    /// Totals grouped by one dimension, ordered by the first measure descending.
    ///
    /// Where the cardinality ceiling elides names, a single overflow row
    /// collects the remainder and `meta.truncated` reads true. That row's
    /// `values` is **sparse** — see ``MetricBreakdownItem/isOverflow``.
    ///
    /// - Note: A breakdown response carries `meta.granularity` too, resolved to
    ///   `day` when the caller sends none. It buckets nothing here; the server
    ///   echoes it.
    public func breakdown(
        measures: [MetricMeasure],
        dimension: MetricDimension,
        granularity: MetricGranularity? = nil,
        status: [FeedbackStatus] = [],
        category: [FeedbackCategory] = [],
        eventName: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        days: Int? = nil
    ) async throws -> MetricBreakdown {
        let query = MetricsQuery(
            measures: measures, granularity: granularity, dimension: dimension,
            status: status, category: category, eventName: eventName,
            dateFrom: dateFrom, dateTo: dateTo, days: days
        )
        return try await client.get(path: "/metrics/breakdown", queryItems: try query.items())
    }

    /// The raw event feed, paginated.
    ///
    /// The response carries two meta blocks — pagination under `meta`, the
    /// metrics block under `metrics`. `perPage` is clamped client-side to
    /// 1...200 as a convenience; the server answers a 400 rather than clamping.
    ///
    /// To page a live feed without double-counting, pin `dateTo` to a fixed
    /// instant for the whole walk and advance it only when starting a new one.
    public func events(
        measures: [MetricMeasure],
        status: [FeedbackStatus] = [],
        category: [FeedbackCategory] = [],
        eventName: String? = nil,
        dateFrom: String? = nil,
        dateTo: String? = nil,
        days: Int? = nil,
        page: Int? = nil,
        perPage: Int? = nil
    ) async throws -> MetricEventList {
        let query = MetricsQuery(
            measures: measures, status: status, category: category, eventName: eventName,
            dateFrom: dateFrom, dateTo: dateTo, days: days, page: page, perPage: perPage
        )
        return try await client.get(path: "/metrics/events", queryItems: try query.items())
    }
}
