# Getting started with SwiftlyFeedbackKit for Vapor

This guide matches the sources in this checkout. The compiled copy of every Swift sample is [`Examples/GettingStarted`](../Examples/GettingStarted). From that directory, `swift build` type-checks them on Linux.

## What you are installing

The package is not on a registry. The public mirror is [SwiftlyFeedbackKit-Vapor-SDK](https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK).

| | |
|---|---|
| Newest tag on that mirror | `3.0.0` (14 October 2026) |
| `main` on that mirror | the `3.0.0` sources |
| Earlier tags | `2.0.0` and `1.1.1`: neither has the API in this guide |

Pin `.package(..., from: "3.0.0")`. `from: "2.0.0"` stays on 2.x. Tags `1.1.1` and `2.0.0` do not include metrics, `PUT /auth/password`, comment `X-User-Id`, `sync_states`, or the per-call JSON coder. This guide documents the 3.0.0 sources here.

## Requirements

- Swift 6.2 or later. The package builds on Linux.
- macOS 13 or later when building for Apple platforms. `Package.swift` lists that minimum only. SwiftPM does not treat it as "macOS and nothing else".
- Vapor 4.89 or later.

## Add the package

[`Examples/GettingStarted/Package.swift`](../Examples/GettingStarted/Package.swift) is a complete manifest. `../..` is this package when the example stays where it is. A host app that sits next to a checkout uses `.package(path: "../SwiftlyFeedbackKit-Vapor")` instead. The product name is `SwiftlyFeedbackKitVapor` either way.

For a path dependency, the `package:` argument is the directory name, `SwiftlyFeedbackKit-Vapor`. For the git URL, it is `SwiftlyFeedbackKit-Vapor-SDK`, which is not the `name` in this package's own `Package.swift` (`SwiftlyFeedbackKitVapor`).

```swift
// swift-tools-version:6.2
import PackageDescription

// Compiled by `swift build` in this directory. `../..` is the
// SwiftlyFeedbackKit-Vapor package that contains this example.
// A host app that sits next to a checkout of the package uses
// `.package(path: "../SwiftlyFeedbackKit-Vapor")` instead. The product
// name stays `SwiftlyFeedbackKitVapor`. The `package:` argument is the
// path's directory name for a path dependency, and
// `SwiftlyFeedbackKit-Vapor-SDK` for the git URL.
let package = Package(
    name: "GettingStarted",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    ],
    targets: [
        .executableTarget(
            name: "GettingStarted",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftlyFeedbackKitVapor", package: "SwiftlyFeedbackKit-Vapor"),
            ]
        ),
    ]
)
```

The published pin is a URL dependency on `https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK.git` with `from: "3.0.0"`, and a product `SwiftlyFeedbackKitVapor` whose `package` argument is `SwiftlyFeedbackKit-Vapor-SDK`. Tags `1.1.1` and `2.0.0` do not contain the calls in the samples below.

## Configure

Call `configure` once, from `configure.swift`, before any request uses the client. The value is stored on `Application`. A request that runs before `configure` throws `FeedbackKitError.notConfigured`.

```swift
func configureFeedbackKit(_ app: Application) {
    app.feedbackKit.configure(
        apiKey: Environment.get("FEEDBACKKIT_API_KEY") ?? "",
        environment: .production
    )
}
```

| Environment | Base URL |
|---|---|
| `.local` | `http://localhost:8080` |
| `.development` | `https://api.dev.getfeedbackkit.com` |
| `.testflight` | `https://api.testflight.getfeedbackkit.com` |
| `.production` | `https://api.prod.getfeedbackkit.com` |
| `.custom(URL)` | The URL you pass |

The client appends `api/v1` itself. Pass the origin, not a URL that already ends in `/api/v1`.

`req.feedbackKit` is the X-API-Key client. It throws when the app has not been configured. `req.feedbackKitAdmin(token:)` is the Bearer client and throws for the same reason. Outside a request, use `app.feedbackKit.client()` and `app.feedbackKit.adminClient(token:)`.

## Submit and list feedback

`create` sends `userId` as `X-User-Id` and in the JSON body. `list` and `get` send `X-User-Id` only when you pass `userId`. The server uses that header for `hasVoted` and for showing the creator an item hidden over the Free-tier cap.

`feedback.delete(id:)` is deprecated. It throws `FeedbackKitError.operationNotSupported` and does not send a request. Delete with the admin client's `feedback.delete(id:)`.

```swift
func feedbackRoutes(_ app: Application) throws {
    app.get("feedback") { req async throws -> [FeedbackResponse] in
        let sdk = try req.feedbackKit
        return try await sdk.feedback.list(status: .approved, userId: "user-123")
    }

    app.get("feedback", ":id") { req async throws -> FeedbackResponse in
        let id = try req.parameters.require("id", as: UUID.self)
        return try await req.feedbackKit.feedback.get(id: id, userId: "user-123")
    }

    app.post("feedback") { req async throws -> FeedbackResponse in
        let sdk = try req.feedbackKit
        return try await sdk.feedback.create(CreateFeedbackRequest(
            title: "Server-detected issue",
            description: "Automatically reported by monitoring",
            category: .bugReport,
            userId: "system-monitor"
        ))
    }
}
```

## Votes

```swift
func voteAndUnvote(_ req: Request) async throws {
    let feedbackId = UUID()
    let voted = try await req.feedbackKit.votes.vote(
        feedbackId: feedbackId,
        request: CreateVoteRequest(
            userId: "user-123",
            email: "user@example.com",
            notifyStatusChange: true
        )
    )
    let removed = try await req.feedbackKit.votes.unvote(
        feedbackId: feedbackId,
        request: CreateVoteRequest(userId: "user-123")
    )
    _ = (voted, removed)
}
```

## Comments and `X-User-Id`

`comments.list(feedbackId:userId:)` sends `X-User-Id` when `userId` is set. `comments.create` always sends `request.userId` as that header and in the body. The hidden-over-limit guard reads the header, not the body. A header that disagrees with the body is rejected.

`isAdmin: true` on this X-API-Key call is accepted only while the server's `COMMENT_ADMIN_REPLY_REQUIRE_USER` flag is off (the default). When that flag is on, an admin reply needs a Bearer token for a project owner, admin, or member.

`comments.delete` needs `userId` or `bearerToken`. `userId` deletes that SDK user's own non-admin comment and sends `X-API-Key` plus `X-User-Id`. `bearerToken` deletes any comment as a project owner or admin and sends `Authorization: Bearer` with no API key. A token wins when both are set. Calling with neither throws `FeedbackKitError.operationNotSupported` before a request is sent.

```swift
func commentsWithUserHeader(_ req: Request) async throws {
    let feedbackId = UUID()
    let commentId = UUID()
    let comments = try await req.feedbackKit.comments.list(
        feedbackId: feedbackId,
        userId: "user-123"
    )
    let comment = try await req.feedbackKit.comments.create(
        feedbackId: feedbackId,
        request: CreateCommentRequest(
            content: "Acknowledged by server",
            userId: "user-123",
            isAdmin: true
        )
    )
    try await req.feedbackKit.comments.delete(
        feedbackId: feedbackId,
        commentId: commentId,
        userId: "user-123"
    )
    _ = (comments, comment)
}
```

```swift
func deleteCommentAsOwner(_ req: Request) async throws {
    let feedbackId = UUID()
    let commentId = UUID()
    let bearerToken = "token"
    try await req.feedbackKit.comments.delete(
        feedbackId: feedbackId,
        commentId: commentId,
        bearerToken: bearerToken
    )
}
```

## Users, events, and sync states

```swift
func registerSDKUser(_ req: Request) async throws {
    let user = try await req.feedbackKit.users.register(
        RegisterSDKUserRequest(userId: "user-123", mrr: 29.99)
    )
    _ = user
}
```

```swift
func trackEvent(_ req: Request) async throws {
    let event = try await req.feedbackKit.events.track(
        TrackViewEventRequest(
            eventName: "api_request",
            userId: "user-123",
            properties: ["endpoint": "/checkout", "method": "POST"]
        )
    )
    _ = event
}
```

`FeedbackResponse.syncStates` decodes the optional `sync_states` array. Each `FeedbackSyncState` has `provider`, `state`, and `providerRefUrl` (the spelling `.convertFromSnakeCase` binds for `provider_ref_url`). Older servers omit the key, and the property stays `nil`.

```swift
func readSyncStates(_ req: Request) async throws {
    let feedbackId = UUID()
    let item = try await req.feedbackKit.feedback.get(id: feedbackId, userId: "user-123")
    for state in item.syncStates ?? [] {
        let ref = state.providerRefUrl ?? ""
        print(state.provider, state.state, ref)
    }
}
```

## Metrics

Four reads on `req.feedbackKit.metrics`. `measures` is required. The key identifies the project, so these methods take no project id.

`MetricSummary`, `MetricSeriesPoint`, and `MetricBreakdownItem` subscript with a `MetricMeasure` and return `Double?`. A breakdown overflow row (`isOverflow`) omits `unique_event_users`, so `item[.uniqueEventUsers]` is `nil` there.

`MetricsMeta` is on `summary.meta`, `series.meta`, `breakdown.meta`, and on an event page under `metrics` (pagination is `page.meta`). `granularity` is absent on a summary and on an event page. It is present on a timeseries and echoed on a breakdown. A series point is `bucket` plus `values`. There is no `bucket_start`.

Quiet buckets are present and zero-valued. Check `series.series`, the array, not the `MetricSeries` value itself.

A Free-plan read is HTTP 200 with `meta.resolvedEventScope == .predefinedOnly`. Read `meta.retentionWindowDays` (Free 30, Pro 90, Team 365). `meta.retentionClamped` is true only when this request was narrowed. Re-requesting an already-clamped window returns the same window with the flag false.

`FeedbackKitError.tierUpgradeRequired` is the enveloped 402 for a breakdown by `eventName`, a custom `eventName` filter, and the raw event feed. `FeedbackKitError.rateLimited` is 60 requests per 60 seconds for this family. The Bearer metrics family has its own budget. `POST /events/track` is in neither.

Pin `dateTo` while paging a live feed.

```swift
func metricsReads(_ req: Request) async throws {
    let summary = try await req.feedbackKit.metrics.summary(
        measures: [.feedbackCount, .voteCount, .eventCount],
        days: 30
    )
    let feedbackCount = summary[.feedbackCount] ?? 0
    print(feedbackCount)
    let windowDays = summary.meta.retentionWindowDays
    let clamped = summary.meta.retentionClamped
    _ = (windowDays, clamped)

    let series = try await req.feedbackKit.metrics.timeseries(
        measures: [.eventCount],
        granularity: .day,
        days: 14
    )
    if series.series.allSatisfy({ ($0[.eventCount] ?? 0) == 0 }) {
        print("quiet window")
    }

    let breakdown = try await req.feedbackKit.metrics.breakdown(
        measures: [.eventCount, .uniqueEventUsers],
        dimension: .eventName,
        days: 30
    )
    for item in breakdown.items where item.isOverflow {
        _ = item[.uniqueEventUsers]
    }

    let page = try await req.feedbackKit.metrics.events(
        measures: [.eventCount],
        dateFrom: "2024-01-01T00:00:00Z",
        dateTo: "2024-02-01T00:00:00Z",
        page: 1,
        perPage: 100
    )
    print(page.items.count, page.meta.total, page.metrics.dateFrom)
    _ = page.metrics.granularity
}
```

```swift
func metricsFreePlan(_ summary: MetricSummary) {
    if summary.meta.resolvedEventScope == .predefinedOnly {
        _ = summary.meta.eventScope
    }
}
```

```swift
func pageMetricsFeed(_ req: Request, since: String) async throws {
    let until = ISO8601DateFormatter().string(from: Date())
    var page = 1
    while true {
        let batch = try await req.feedbackKit.metrics.events(
            measures: [.eventCount],
            dateFrom: since,
            dateTo: until,
            page: page,
            perPage: 200
        )
        if batch.items.isEmpty { break }
        page += 1
    }
}
```

Bearer metrics take a `projectId` and can request `sdkUserCount`, `mrrSum`, `mrrAverage`, and `usersWithMrr`. The same four measures on `req.feedbackKit.metrics` come back as `FeedbackKitError.measureNotAvailable`.

```swift
func adminMetricsReads(_ req: Request) async throws {
    let bearerToken = "token"
    let projectId = UUID()
    let admin = try req.feedbackKitAdmin(token: bearerToken)
    let revenue = try await admin.metrics.summary(
        projectId: projectId,
        measures: [.sdkUserCount, .mrrSum, .mrrAverage, .usersWithMrr],
        days: 30
    )
    print(revenue[.mrrSum] ?? 0)
    let series = try await admin.metrics.timeseries(
        projectId: projectId,
        measures: [.feedbackCount],
        granularity: .week,
        days: 90
    )
    _ = series
}
```

`admin.events.stats` returns `ViewEventsOverview`. `eventScope`, `retentionClamped`, and `retentionWindowDays` are optional so a response from a server that does not send them still decodes.

## Change a password

`auth.changePassword` sends `PUT /auth/password` with `current_password` and `new_password`. It returns nothing on success. Login is unauthenticated, so the token you pass to `feedbackKitAdmin` can be empty for that one call. Use the token from the login response after that.

```swift
func loginAndChangePassword(_ req: Request) async throws {
    let auth = try await req.feedbackKitAdmin(token: "").auth.login(
        LoginRequest(email: "admin@example.com", password: "password")
    )
    let token = auth.token
    let admin = try req.feedbackKitAdmin(token: token)
    let me = try await admin.auth.me()
    try await admin.auth.changePassword(
        ChangePasswordRequest(currentPassword: "password", newPassword: "a-new-password")
    )
    _ = me
}
```

`auth.deleteAccount` sends `DELETE /auth/account` with the current password. `auth.resendVerification` sends `POST /auth/resend-verification`.

## Outside a request

```swift
func outsideRequestContext(_ app: Application) async throws {
    let savedToken = "token"
    let sdk = try app.feedbackKit.client()
    let feedback = try await sdk.feedback.list()
    let admin = try app.feedbackKit.adminClient(token: savedToken)
    let dashboard = try await admin.dashboard.home()
    _ = (feedback, dashboard)
}
```

## Errors

Every API method throws `FeedbackKitError`, which conforms to `AbortError`. Status mapping:

| Case | Status |
|---|---|
| `badRequest(message:)` | 400 |
| `unauthorized`, `invalidApiKey` | 401 |
| `paymentRequired(message:)` | 402, boolean body |
| `tierUpgradeRequired(code:message:)` | 402, enveloped metrics body |
| `forbidden` | 403, role or suspended project |
| `measureNotAvailable(measure:message:)` | 403, measure needs Bearer |
| `notFound` | 404 |
| `conflict` | 409 |
| `rateLimited(message:)` | 429 |
| `serverError(statusCode:)` | other, including 422 |
| `decodingError` | thrown locally after a 2xx body fails to decode |
| `notConfigured` | thrown locally |
| `operationNotSupported` | thrown locally, before a request |

Which error body arrived is decided by the JSON type of `error`, not by the status. 402 and 403 arrive in both shapes.

```swift
func handleFeedbackKitError(_ req: Request) async throws {
    let request = CreateFeedbackRequest(
        title: "Server-detected issue",
        description: "Automatically reported by monitoring",
        category: .bugReport,
        userId: "system-monitor"
    )
    do {
        _ = try await req.feedbackKit.feedback.create(request)
    } catch let error as FeedbackKitError {
        switch error {
        case .badRequest:
            break
        case .paymentRequired:
            break
        case .unauthorized, .invalidApiKey:
            break
        case .tierUpgradeRequired:
            break
        case .measureNotAvailable:
            break
        case .forbidden:
            break
        case .rateLimited:
            break
        case .conflict:
            break
        case .notFound:
            break
        case .serverError:
            break
        case .decodingError:
            break
        case .notConfigured:
            break
        case .operationNotSupported:
            break
        }
    }
}
```

## Logging

The client logs through the `Logger` it was given. Inside a request that is `req.logger`. From `app.feedbackKit.client()` and `adminClient(token:)` it is `app.logger`.

The only line is at `.error`, and only when a 2xx body fails to decode. The message is `FeedbackKit failed to decode` plus the type name. The decode error's description is not logged, because it can include response field values. The thrown `FeedbackKitError.decodingError` still carries that detail for the caller.

There is no other log line. The package uses swift-log via Vapor. It does not use Apple's unified logging.
