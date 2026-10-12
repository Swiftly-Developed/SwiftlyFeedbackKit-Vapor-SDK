# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-08-25

> This section describes the sources in this checkout. It is **not a published tag**. The public mirror's newest tag remains [1.1.1](https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK/releases/tag/1.1.1). Do not pin `from: "2.0.0"`.

> ⚠️ **Release precondition — read before upgrading.** This version's headline feature is the
> metrics read API, and the metrics endpoints are **not yet deployed to every environment**.
> Measured 2026-08-25: the development API serves them; the **testflight and production APIs
> answer `404`** to `/api/v1/metrics/summary` while their `/health` answers `200`, so the routes
> are genuinely absent rather than the service being down. Until that deploy lands, a metrics call
> against production fails. Every other change in this release is unaffected.

### Added

- **Metrics reads, on both authentication surfaces.** Four operations per realm — `summary`, `timeseries`, `breakdown` and `events` — reached through `req.feedbackKit.metrics` (X-API-Key, scoped to the project the key identifies) and `req.feedbackKitAdmin(token:).metrics` (Bearer, taking a `projectId`). The Bearer realm additionally serves the revenue and audience measures — `sdkUserCount`, `mrrSum`, `mrrAverage`, `usersWithMrr` — which the X-API-Key realm refuses with the new `FeedbackKitError.measureNotAvailable`. Both families are capped at 60 requests per 60 seconds, on separate budgets. `POST /events/track` is not in either group.
- **The metrics response models** — `MetricSummary`, `MetricSeries` / `MetricSeriesPoint`, `MetricBreakdown` / `MetricBreakdownItem`, `MetricEventList` / `MetricPaginationMeta`, and the `MetricsMeta` block they all carry. Three shapes are easy to get wrong and are worth stating: `meta.granularity` is **absent** on a summary and on an event-feed page (omitted, never `null`), a series point is exactly `bucket` plus `values` with no `bucket_start`, and the event feed carries **two** meta blocks — pagination under `meta`, the metrics block under `metrics`.
- **Typed measure accessors, all optional-returning.** `summary[.feedbackCount]`, `point[.eventCount]`, `item[.uniqueEventUsers]` return `Double?`, because `values` is sparse by design: a breakdown's overflow row omits `unique_event_users` entirely, since a distinct-user count is not additive across elided names.
- **The closed vocabularies** — `MetricMeasure` (9), `MetricGranularity` (`hour`/`day`/`week`/`month`), `MetricDimension`, `MetricEventScope`, and `PredefinedEventName`, FeedbackKit's three reserved event names as typed constants.
- A Free-plan metrics read is a **success**: the response arrives `200` with `meta.eventScope` reading `predefined_only` and, where the window was narrowed, `meta.retentionClamped` set. Read `meta.retentionWindowDays` rather than hardcoding 30, 90, or 365, and never derive `retentionClamped` by comparing the request to the response — re-requesting an already-clamped window returns the same window with the flag `false`. The allowances the server declares are Free 30 days, Pro 90 days, Team 365 days.

### Fixed

- **`AuthAPI.changePassword` never changed a password** (1.1.0, 1.1.1, and the unreleased 2.0.0 sources). It `POST`ed `/auth/password` with an empty body. The server registers `PUT /auth/password` and decodes `current_password` / `new_password`. The call now sends that PUT.
- **Comments on feedback hidden over the Free cap 404'd for the creator** (1.1.0, 1.1.1, and the unreleased 2.0.0 sources). `CommentAPI.create` put the user id in the JSON body only, and `list` had no way to send one. The server's hidden-item guard reads `X-User-Id` and does not look at the body. Create now sends the request's user id as that header, and `list(feedbackId:userId:)` sends it when the caller passes one.
- **`CommentAPI.delete` requires `userId` or `bearerToken`.** Calling with neither throws `FeedbackKitError.operationNotSupported` before a request is sent. `userId` deletes that SDK user's own non-admin comment and sends `X-API-Key` plus `X-User-Id`. `bearerToken` deletes any comment as a project owner or admin and sends `Authorization: Bearer` with no API key. A token wins when both are set. The key-only delete this client used to send cannot prove who is deleting.
- **`SubscriptionAPI.portal(returnUrl:)` truncated return URLs that contained `&`** (1.1.0, 1.1.1, and the unreleased 2.0.0 sources). The query was concatenated raw. It now goes through the same percent-encoding as the other query builders. The key stays `returnUrl`, which is what `CreatePortalSessionDTO` decodes.
- **Event stats dropped the retention meta.** `ViewEventsOverview` now decodes `event_scope`, `retention_clamped`, and `retention_window_days`. All three are optional, so a response from a server that does not send them still decodes.
- **Feedback responses dropped `sync_states`.** `FeedbackResponse.syncStates` decodes the optional per-provider outbox rows. Absent on older payloads.
- **The JSON coder is no longer one shared instance.** `JSONDecoder` and `JSONEncoder` are classes; a Vapor host decodes concurrent requests. Each use now builds its own.
- **Decode failures no longer log the error description**, which can include response field values. The log names the type that failed; the thrown `FeedbackKitError.decodingError` still carries the detail for the caller.

- **`SDKUsersStats` never decoded** — every `AdminUserAPI.stats`/`allStats` call threw `keyNotFound`. The properties `totalMRR`/`usersWithMRR`/`averageMRR` are renamed to `totalMrr`/`usersWithMrr`/`averageMrr`: the server sends `total_mrr` etc., and the decoder's `.convertFromSnakeCase` strategy resolves those keys to the lowercase-acronym spellings, so the uppercase-run names could never bind. (Source-breaking rename, but no working code could have referenced the old names — the decode always threw first.)
- **`ProjectResponse.slackWebhookURL` was permanently `nil`** on every project read (same snake_case/acronym mechanism, silent because the property is Optional). Renamed to `slackWebhookUrl`, matching the package's existing `logoUrl`/`embedUrl`/`slackWebhookUrl` (request-side) convention.
- **One unknown feedback row no longer poisons a whole list.** `FeedbackAPI.list` previously decoded via a bare `decode([FeedbackResponse].self)`, so a single row whose `status` or `category` carried a token newer than this SDK failed the entire call. It now uses a tolerant element-drop decode: unknown-enum rows are dropped (order preserved); genuinely malformed rows (missing key, type mismatch) still throw.
- **Query values are now percent-encoded.** Query strings were built by string concatenation, so four classes of value reached the server corrupted, all silently and with no error:
  - a value containing **`&`** (or `=`) **injected an extra parameter** — `a&b=c` arrived as two parameters, not one value;
  - a value containing **`#`** was **truncated** at the `#`, and everything after it never left the client at all;
  - a value containing **`+`** arrived as a **space**, because the server's form parser plus-decodes before percent-decoding;
  - a value containing a literal **`%`** was **double-decoded** — `100%20done` arrived as `100 done`.

  Values that were already correct are unaffected: spaces, accented characters and emoji round-tripped before this change and still do, and the bytes sent for every other request are byte-for-byte unchanged. Affected call sites: `FeedbackAPI.list`, `AdminEventAPI.stats`, `AdminEventAPI.allStats`. The `includeMerged` key keeps its existing camelCase spelling — that is a separate, unresolved question and deliberately not changed here.

### Deprecated

- **`FeedbackAPI.delete(id:)`** — this operation has never worked: the server registers `DELETE /feedbacks/:id` behind Bearer authentication only, so the X-API-Key call was rejected with 401 on every invocation since 1.0.0. It now throws `FeedbackKitError.operationNotSupported` immediately instead of issuing the doomed request. Deletion is an admin action — use `FeedbackKitAdmin`'s `feedback.delete(id:)`.

### Added

- `FeedbackKitError.operationNotSupported(String)` — thrown client-side, before any request, by operations the SDK's auth surface can never perform.
- **The metrics error envelope's `code` is now read.** The server answers some requests with an enveloped body — `error` is an *object* carrying `code`, `message` and `field` — rather than the boolean `{ error: true, reason: … }` shape. That body previously failed the SDK's only decode outright, so the machine-readable code was invisible and the human-readable message was lost. Both bodies are now decoded, and which one arrived is decided by the JSON type of `error`, never by the status code — 402 and 403 arrive in both shapes.
- `FeedbackKitError.tierUpgradeRequired(code:message:)` — the enveloped 402 (`METRICS_CUSTOM_EVENTS_REQUIRE_PRO`). The boolean-shaped 402 still maps to `paymentRequired(message:)`, unchanged.
- `FeedbackKitError.measureNotAvailable(measure:message:)` — the enveloped 403 (`METRICS_MEASURE_REQUIRES_BEARER`), a refusal by *authentication surface* rather than by role. The boolean-shaped 403 — a role denial or a suspended project — still maps to `forbidden`, unchanged, so the two 403s stay distinguishable.
- `FeedbackKitError.rateLimited(message:)` — see **Changed**.

### Changed

- **A 429 now surfaces as `FeedbackKitError.rateLimited(message:)` rather than `serverError(statusCode: 429)`.** Host applications matching on `serverError` to detect a throttled request will stop seeing 429 there. This is a host-observable behaviour change even though it is an improvement, so it is recorded rather than folded into **Fixed**. `422` is deliberately unchanged and still maps to `serverError(statusCode: 422)`.

  The X-API-Key metrics family and the Bearer metrics family are each capped at 60 requests per 60 seconds. The budgets are not shared. The rest of the Bearer admin surface is not on that limiter, and `POST /events/track` is not in either group.

## [1.1.1] - 2026-04-24

### Fixed

- Removed the empty `SwiftlyFeedbackKitVaporTests` test target from `Package.swift`. It had no backing `Tests/` directory, which caused Swift 6.2 / Xcode 26 to report overlapping sources when building locally. Consumers using this package as a SwiftPM dependency were unaffected; this only fixes local `swift build`.

### Changed

- Version alignment with Swift SDK 1.1.1 hotfix (Xcode 26 / Swift 6.2 compatibility). No other functional changes.

## [1.1.0] - 2026-04-15

### Added

- LICENSE file (MIT)
- CHANGELOG.md following Keep a Changelog format
- CONTRIBUTING.md with contribution guidelines
- SECURITY.md with vulnerability reporting policy
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- SUPPORT.md with support channels
- Package.swift metadata comment block

### Changed

- Migrated API URLs to getfeedbackkit.com
- Standardized documentation across all FeedbackKit SDKs

## [1.0.0] - 2026-02-14

### Added

- Initial release of FeedbackKit Vapor SDK
- **SDK Operations** (X-API-Key authenticated)
  - Feedback: list, get, submit
  - Voting: vote and unvote
  - Comments: list and create
  - SDK user registration
  - Event tracking
- **Admin Operations** (Bearer token authenticated)
  - Authentication (register, login, token management)
  - Project management (CRUD, API keys)
  - Member and invite management
  - Dashboard and analytics
  - Feedback management with status updates
  - Subscription information
  - Integration management (Slack, GitHub, Notion, ClickUp, Linear, Monday.com, Trello, Airtable, Asana, Basecamp)
- Environment configuration (production, staging, local, custom)
- FeedbackKitError typed error handling
- Usage outside Vapor request context
- Swift 6.2 concurrency support
- macOS 13+ platform support

[1.1.1]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK/releases/tag/1.1.1
[1.1.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK/releases/tag/1.1.0
[1.0.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK/releases/tag/1.0.0
