# SwiftlyFeedbackKit for Vapor

> **This README matches the source in this repository.** It is not a registry package. The public mirror's newest tag is **1.1.1**. There is no `2.0.0` tag, so `from: "2.0.0"` does not resolve. Tag `1.1.1` does not include metrics, `PUT /auth/password`, comment `X-User-Id`, `sync_states`, or the per-call JSON coder. Walk through a host app in [docs/getting-started.md](docs/getting-started.md). Every Swift sample below is copied from [`Examples/GettingStarted`](Examples/GettingStarted), which `swift build` type-checks.

A server-side Swift SDK for integrating [FeedbackKit](https://getfeedbackkit.com) into your [Vapor](https://vapor.codes) applications. Submit feedback, manage votes and comments, track events, and administer projects — all from your server-side Swift code.

## Requirements

- Swift 6.2+ (Swift 6 language mode; the package builds on Linux)
- macOS 13+ when building for Apple platforms. `Package.swift` lists that minimum only — SwiftPM does not treat it as "macOS and nothing else", and this package is what a Linux Vapor app links.
- Vapor 4.89+

## Installation

Add the package to your `Package.swift`:

Depend on this checkout by path while the mirror is behind. [`Examples/GettingStarted/Package.swift`](Examples/GettingStarted/Package.swift) is the manifest `swift build` actually resolves. A host app next to the checkout uses `.package(path: "../SwiftlyFeedbackKit-Vapor")` instead of `../..`. The product name is `SwiftlyFeedbackKitVapor`. For a path dependency the `package:` argument is the directory name `SwiftlyFeedbackKit-Vapor`. For the git URL it is `SwiftlyFeedbackKit-Vapor-SDK`, which is not the `name` in this package's `Package.swift`.

The published pin is `from: "1.1.1"` on `https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK.git` with `package: "SwiftlyFeedbackKit-Vapor-SDK"`. The samples below do not compile against that tag.

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

## Quick Start

### Configuration

Configure FeedbackKit in your Vapor app's `configure.swift`:

`configure` stores the API key on `Application`. A call before that throws `FeedbackKitError.notConfigured`. The client appends `api/v1` to the environment's origin.

```swift
func configureFeedbackKit(_ app: Application) {
    app.feedbackKit.configure(
        apiKey: Environment.get("FEEDBACKKIT_API_KEY") ?? "",
        environment: .production
    )
}
```

### Available Environments

| Environment | URL |
|-------------|-----|
| `.local` | `http://localhost:8080` |
| `.development` | `https://api.dev.getfeedbackkit.com` |
| `.testflight` | `https://api.testflight.getfeedbackkit.com` |
| `.production` | `https://api.prod.getfeedbackkit.com` |
| `.custom(URL)` | Any custom URL |

## SDK Operations (X-API-Key)

These operations authenticate with the project API key configured during setup.

### Feedback

`create` sends `userId` as `X-User-Id` and in the body. `list` and `get` send the header only when you pass `userId`. The server uses it for `hasVoted` and for showing the creator an item hidden over the Free-tier cap.

`feedback.delete(id:)` is deprecated. It throws `FeedbackKitError.operationNotSupported` and does not send a request. Delete with `FeedbackKitAdmin.feedback.delete(id:)`.

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

### Voting

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

### Comments

`comments.list(feedbackId:userId:)` sends `X-User-Id` when `userId` is set. `comments.create` always sends `request.userId` as that header and in the body. The hidden-over-limit guard reads the header, not the body. A header that disagrees with the body is rejected.

`isAdmin: true` on this X-API-Key call is accepted only while the server's `COMMENT_ADMIN_REPLY_REQUIRE_USER` flag is off (the default). When that flag is on, an admin reply needs a Bearer token for a project owner, admin, or member.

`comments.delete` needs `userId` or `bearerToken`. `userId` deletes that SDK user's own non-admin comment (`X-API-Key` and `X-User-Id`). `bearerToken` deletes any comment as a project owner or admin (`Authorization: Bearer`, no API key). A token wins when both are set. Calling with neither throws `FeedbackKitError.operationNotSupported` before a request is sent.

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

### SDK User Registration

```swift
func registerSDKUser(_ req: Request) async throws {
    let user = try await req.feedbackKit.users.register(
        RegisterSDKUserRequest(userId: "user-123", mrr: 29.99)
    )
    _ = user
}
```

### Event Tracking

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

### Sync states

`FeedbackResponse.syncStates` decodes the optional `sync_states` array. Each row is `provider`, `state`, and `providerRefUrl` (the spelling `.convertFromSnakeCase` binds for `provider_ref_url`). Older payloads omit the key and the property stays `nil`.

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

### Metrics (X-API-Key)

Four reads on `req.feedbackKit.metrics`. `measures` is required. The key identifies the project, so these methods take no project id.

`MetricSummary`, `MetricSeriesPoint`, and `MetricBreakdownItem` subscript with a `MetricMeasure` and return `Double?`. A breakdown overflow row (`isOverflow`) omits `unique_event_users`, so `item[.uniqueEventUsers]` is `nil` there.

`MetricsMeta` is on `summary.meta`, `series.meta`, `breakdown.meta`, and on an event page under `metrics` (pagination is `page.meta`). `granularity` is absent on a summary and on an event page. It is present on a timeseries and echoed on a breakdown. A series point is `bucket` plus `values`. There is no `bucket_start`.

Quiet buckets are present and zero-valued. Check `series.series`, the array of points. `series` itself is a `MetricSeries` and is not a collection.

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


## Admin Operations (Bearer Token)

These operations require a Bearer token from an authenticated admin user.

### Authentication

`auth.changePassword` sends `PUT /auth/password` with `current_password` and `new_password`. It returns nothing on success. Login is unauthenticated, so the token you pass to `feedbackKitAdmin` can be empty for that one call. Use the token from the login response after that.

`auth.deleteAccount` sends `DELETE /auth/account` with the current password. `auth.resendVerification` sends `POST /auth/resend-verification`.

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

### Projects

```swift
func projectAdmin(_ req: Request) async throws {
    let bearerToken = "token"
    let projectId = UUID()
    let admin = try req.feedbackKitAdmin(token: bearerToken)
    let projects = try await admin.projects.list()
    let project = try await admin.projects.create(
        CreateProjectRequest(name: "My App", description: "User feedback for My App")
    )
    let archived = try await admin.projects.archive(id: projectId)
    let restored = try await admin.projects.unarchive(id: projectId)
    let updated = try await admin.projects.regenerateKey(id: projectId)
    _ = (projects, project, archived, restored, updated)
}
```

### Members & Invites

```swift
func memberAdmin(_ req: Request) async throws {
    let bearerToken = "token"
    let projectId = UUID()
    let memberId = UUID()
    let admin = try req.feedbackKitAdmin(token: bearerToken)
    let response = try await admin.members.add(
        projectId: projectId,
        AddMemberRequest(email: "dev@example.com", role: .member)
    )
    let member = try await admin.members.updateRole(
        projectId: projectId,
        memberId: memberId,
        UpdateMemberRoleRequest(role: .admin)
    )
    let invites = try await admin.members.listInvites(projectId: projectId)
    _ = (response, member, invites)
}
```

### Dashboard & Analytics

`users.stats` returns `SDKUsersStats`. The money fields are `totalMrr`, `usersWithMrr`, and `averageMrr`. Those spellings are what `.convertFromSnakeCase` binds for `total_mrr`, `users_with_mrr`, and `average_mrr`.

`events.stats` returns `ViewEventsOverview`. `eventScope`, `retentionClamped`, and `retentionWindowDays` are optional so a response from a server that does not send them still decodes.

```swift
func dashboardAdmin(_ req: Request) async throws {
    let bearerToken = "token"
    let projectId = UUID()
    let admin = try req.feedbackKitAdmin(token: bearerToken)
    let dashboard = try await admin.dashboard.home()
    print(dashboard.totalFeedback, dashboard.totalUsers)
    let stats = try await admin.dashboard.project(id: projectId)
    let userStats = try await admin.users.stats(projectId: projectId)
    print(userStats.totalMrr.formatted(.currency(code: "USD")))
    let eventStats = try await admin.events.stats(projectId: projectId, days: 30)
    _ = (stats, eventStats.retentionWindowDays, eventStats.eventScope, eventStats.retentionClamped)
}
```

### Metrics (Bearer, per project)

The same four reads, scoped to one project by its identifier, through the admin
credential. Two differences make this family worth reaching for:

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

- **The four Bearer-only measures** — `sdkUserCount`, `mrrSum`, `mrrAverage`,
  `usersWithMrr` — succeed here. Requesting one through `req.feedbackKit.metrics`
  answers `FeedbackKitError.measureNotAvailable`, which is a *surface* refusal,
  distinct from both the billing refusal (`tierUpgradeRequired`) and a role
  denial (`forbidden`).
- **The same 60 requests per 60 seconds cap applies here.** It is a separate
  budget from the X-API-Key family, not a shared one, and `POST /events/track`
  is not in either group. Over budget the server answers
  `FeedbackKitError.rateLimited`.

Everything else — the empty-bucket shape, the Free-plan `200`, the retention
window, the incremental-sync pattern, the optional measure accessors — is
identical to the X-API-Key family above. The tier gate is the same too: below
Pro, the Bearer family raises the same `tierUpgradeRequired` on the same three
requests.


### Feedback Management (Admin)

```swift
func adminFeedbackWrites(_ req: Request) async throws {
    let bearerToken = "token"
    let feedbackId = UUID()
    let primaryId = UUID()
    let duplicateId1 = UUID()
    let duplicateId2 = UUID()
    let admin = try req.feedbackKitAdmin(token: bearerToken)
    let updated = try await admin.feedback.update(
        id: feedbackId,
        UpdateFeedbackRequest(status: .inProgress)
    )
    let rejected = try await admin.feedback.update(
        id: feedbackId,
        UpdateFeedbackRequest(status: .rejected, rejectionReason: "Duplicate of item 42")
    )
    let merged = try await admin.feedback.merge(
        MergeFeedbackRequest(
            primaryFeedbackId: primaryId,
            secondaryFeedbackIds: [duplicateId1, duplicateId2]
        )
    )
    _ = (updated, rejected, merged)
}
```

### Subscriptions

`subscriptions.portal(returnUrl:)` percent-encodes the query. The key stays `returnUrl`.

```swift
func subscriptionAdmin(_ req: Request) async throws {
    let bearerToken = "token"
    let admin = try req.feedbackKitAdmin(token: bearerToken)
    let sub = try await admin.subscriptions.get()
    print(sub.tier, sub.limits.canCreateProject)
    let checkout = try await admin.subscriptions.createCheckout(
        CreateCheckoutSessionRequest(priceId: "price_xxx", successUrl: "https://myapp.com/success")
    )
    _ = checkout.checkoutUrl
    let portal = try await admin.subscriptions.portal(returnUrl: "https://myapp.com/billing?tab=plan")
    _ = portal.portalUrl
}
```

### Integrations

Ten integration clients live on `admin.integrations`: GitHub, ClickUp, Notion, Monday, Linear, Trello, Airtable, Asana, Basecamp, and Email Campaign. Slack settings are `projects.updateSlack`. HubSpot and Salesforce are not on this client.

```swift
func githubAndLinear(_ req: Request) async throws {
    let bearerToken = "token"
    let projectId = UUID()
    let feedbackId = UUID()
    let id1 = UUID()
    let id2 = UUID()
    let id3 = UUID()
    let admin = try req.feedbackKitAdmin(token: bearerToken)
    let project = try await admin.integrations.github.updateSettings(
        projectId: projectId,
        UpdateGitHubSettingsRequest(
            githubOwner: "my-org",
            githubRepo: "my-repo",
            githubToken: "ghp_xxx",
            githubIsActive: true
        )
    )
    let issue = try await admin.integrations.github.createIssue(
        projectId: projectId,
        CreateGitHubIssueRequest(feedbackId: feedbackId)
    )
    print(issue.issueUrl)
    let result = try await admin.integrations.linear.bulkCreateIssues(
        projectId: projectId,
        BulkCreateLinearIssuesRequest(feedbackIds: [id1, id2, id3])
    )
    print(result.created.count, result.failed.count)
    let workspaces = try await admin.integrations.clickup.workspaces(projectId: projectId)
    if let workspaceId = workspaces.first?.id {
        let spaces = try await admin.integrations.clickup.spaces(
            projectId: projectId,
            workspaceId: workspaceId
        )
        _ = spaces
    }
    _ = project
}
```

## Using Outside Request Context

You can also use FeedbackKit from `Application` directly (e.g., in lifecycle handlers or background jobs):

`app.feedbackKit.client()` and `adminClient(token:)` log with `app.logger`. Inside a request the client uses `req.logger`.

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

## Error Handling

Every API method throws `FeedbackKitError`, which conforms to `AbortError`. Which error body arrived is decided by the JSON type of `error`, not by the status. 402 and 403 arrive in both shapes.

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

## API Reference

### SDK Client (`req.feedbackKit`)

| Module | Methods |
|--------|---------|
| `feedback` | `list(status:category:includeMerged:userId:)`, `get(id:userId:)`, `create`. `delete(id:)` is deprecated and throws `operationNotSupported` |
| `votes` | `vote`, `unvote` |
| `comments` | `list(feedbackId:userId:)`, `create`, `delete(feedbackId:commentId:userId:bearerToken:)` |
| `users` | `register` |
| `events` | `track` |
| `metrics` | `summary`, `timeseries`, `breakdown`, `events` |

### Admin Client (`req.feedbackKitAdmin(token:)`)

| Module | Methods |
|--------|---------|
| `auth` | `signup`, `login`, `me`, `logout`, `verifyEmail`, `resendVerification`, `changePassword` (PUT `/auth/password`), `deleteAccount`, `forgotPassword`, `resetPassword`, `updateNotifications`, `subscription`, `syncSubscription` |
| `projects` | `list`, `get`, `create`, `update`, `delete`, `archive`, `unarchive`, `regenerateKey`, `transferOwnership`, `updateSlack`, `updateStatuses`, `updateEmailNotifyStatuses` |
| `members` | `list`, `add`, `updateRole`, `remove`, `listInvites`, `cancelInvite`, `resendInvite`, `acceptInvite`, `previewInvite` |
| `dashboard` | `home`, `project` |
| `subscriptions` | `get`, `createCheckout`, `portal`, `syncApple` |
| `devices` | `register`, `list`, `delete(id:)`, `delete(token:)` |
| `feedback` | `update`, `delete`, `merge` |
| `users` | `list`, `stats`, `listAll`, `allStats` |
| `events` | `list`, `stats`, `allStats` |
| `metrics` | `summary`, `timeseries`, `breakdown`, `events` |
| `integrations` | `.github`, `.clickup`, `.notion`, `.monday`, `.linear`, `.trello`, `.airtable`, `.asana`, `.basecamp`, `.emailCampaign` |

## Privacy

This package runs on your server, so it does not add a row to an App Store or Play nutrition label by itself. The device SDKs do. Answers for those forms: [App Store privacy](../docs/privacy/APP-STORE-PRIVACY.md), [Google Play Data safety](../docs/privacy/GOOGLE-PLAY-DATA-SAFETY.md).

## License

MIT
