import Foundation

/// The `error.code` vocabulary the metrics surface sends inside the enveloped
/// (shape A) error body.
///
/// These are the **wire** tokens. The server distinguishes more cases than it
/// spells on the wire — three separate Pro refusals all serialise as
/// `METRICS_CUSTOM_EVENTS_REQUIRE_PRO` — so this enum has 17 cases where the
/// server's own detailed vocabulary has 19. The shared wire corpus is the
/// authority; a test asserts set equality against it, so a token added there
/// and forgotten here is visible as a failing set comparison rather than as a
/// silently unrecognised code.
///
/// `internal`: recognising a code changes which `FeedbackKitError` a host sees,
/// but the vocabulary itself is not part of the published surface.
enum MetricsErrorCode: String, CaseIterable, Sendable {
    case bucketLimitExceeded = "METRICS_BUCKET_LIMIT_EXCEEDED"
    case conflictingWindowParams = "METRICS_CONFLICTING_WINDOW_PARAMS"
    case customEventsRequirePro = "METRICS_CUSTOM_EVENTS_REQUIRE_PRO"
    case filterNotAvailableForEndpoint = "METRICS_FILTER_NOT_AVAILABLE_FOR_ENDPOINT"
    case invalidCategory = "METRICS_INVALID_CATEGORY"
    case invalidDate = "METRICS_INVALID_DATE"
    case invalidDateRange = "METRICS_INVALID_DATE_RANGE"
    case invalidEventName = "METRICS_INVALID_EVENT_NAME"
    case invalidPage = "METRICS_INVALID_PAGE"
    case invalidPerPage = "METRICS_INVALID_PER_PAGE"
    case invalidStatus = "METRICS_INVALID_STATUS"
    case measureNotAvailableForEndpoint = "METRICS_MEASURE_NOT_AVAILABLE_FOR_ENDPOINT"
    case measureRequiresBearer = "METRICS_MEASURE_REQUIRES_BEARER"
    case measuresRequired = "METRICS_MEASURES_REQUIRED"
    case unknownDimension = "METRICS_UNKNOWN_DIMENSION"
    case unknownGranularity = "METRICS_UNKNOWN_GRANULARITY"
    case unknownMeasure = "METRICS_UNKNOWN_MEASURE"
}
