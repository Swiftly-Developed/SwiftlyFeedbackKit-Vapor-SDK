import Vapor

/// Metrics reads on the **Bearer** surface, scoped to one project by its
/// identifier.
///
/// The same four reads as `MetricsAPI`, with three differences that are the
/// reason this package ships both:
///
/// - the four revenue and audience measures — `sdk_user_count`, `mrr_sum`,
///   `mrr_average`, `users_with_mrr` — succeed here and answer a typed 403 on
///   the key surface;
/// - a **role denial** is reachable here, and it arrives in the server's other
///   error body: no machine-readable code, so it surfaces as
///   ``FeedbackKitError/forbidden`` and stays distinguishable from the key
///   surface's measure refusal;
/// - the same **60 requests per 60 seconds** limiter as the key family
///   (`RateLimitMiddleware` on the Bearer metrics group). The two budgets are
///   not shared. `POST /events/track` is not in either group.
///
/// The tier gate is the same as the key family's: a request that can only be
/// answered from custom events still answers 402
/// (``FeedbackKitError/tierUpgradeRequired(code:message:)``) below Pro.
///
/// Every call goes through the client's Bearer verb. Crossing this family onto
/// the X-API-Key verb compiles and 401s in production.
public struct AdminMetricsAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    /// Totals over the whole window for one project — one number per measure.
    ///
    /// - Note: The response's `meta` carries no `granularity` on this
    ///   operation — the key is absent, not null.
    public func summary(
        projectId: UUID,
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
        return try await client.adminGet(
            path: "/projects/\(projectId)/metrics/summary", queryItems: try query.items(), token: token
        )
    }

    /// One point per bucket across the window, for one project.
    ///
    /// Quiet buckets are present and zero-valued.
    public func timeseries(
        projectId: UUID,
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
        return try await client.adminGet(
            path: "/projects/\(projectId)/metrics/timeseries", queryItems: try query.items(), token: token
        )
    }

    /// Totals grouped by one dimension, for one project.
    ///
    /// - Note: A breakdown response carries `meta.granularity`, resolved to
    ///   `day` when the caller sends none. It buckets nothing here.
    public func breakdown(
        projectId: UUID,
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
        return try await client.adminGet(
            path: "/projects/\(projectId)/metrics/breakdown", queryItems: try query.items(), token: token
        )
    }

    /// The raw event feed for one project, paginated.
    ///
    /// The response carries two meta blocks — pagination under `meta`, the
    /// metrics block under `metrics`. Pin `dateTo` for the whole walk so a live
    /// feed cannot shift beneath the pagination.
    public func events(
        projectId: UUID,
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
        return try await client.adminGet(
            path: "/projects/\(projectId)/metrics/events", queryItems: try query.items(), token: token
        )
    }
}
