# SwiftlyFeedbackKit for Vapor

A server-side Swift SDK for integrating [FeedbackKit](https://getfeedbackkit.com) into your [Vapor](https://vapor.codes) applications. Submit feedback, manage votes and comments, track events, and administer projects — all from your server-side Swift code.

## Requirements

- Swift 6.2+
- macOS 13+
- Vapor 4.89+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Vapor-SDK.git", from: "1.1.0"),
],
targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "SwiftlyFeedbackKitVapor", package: "SwiftlyFeedbackKit-Vapor-SDK"),
        ]
    ),
]
```

## Quick Start

### Configuration

Configure FeedbackKit in your Vapor app's `configure.swift`:

```swift
import SwiftlyFeedbackKitVapor

func configure(_ app: Application) throws {
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

```swift
// List feedback
app.get("feedback") { req async throws -> [FeedbackResponse] in
    let sdk = try req.feedbackKit
    return try await sdk.feedback.list(status: .approved)
}

// Get single feedback
app.get("feedback", ":id") { req async throws -> FeedbackResponse in
    let id = try req.parameters.require("id", as: UUID.self)
    return try await req.feedbackKit.feedback.get(id: id)
}

// Submit feedback
app.post("feedback") { req async throws -> FeedbackResponse in
    let sdk = try req.feedbackKit
    return try await sdk.feedback.create(CreateFeedbackRequest(
        title: "Server-detected issue",
        description: "Automatically reported by monitoring",
        category: .bugReport,
        userId: "system-monitor"
    ))
}
```

### Voting

```swift
// Add a vote
let result = try await req.feedbackKit.votes.vote(
    feedbackId: feedbackId,
    request: CreateVoteRequest(
        userId: "user-123",
        email: "user@example.com",
        notifyStatusChange: true
    )
)

// Remove a vote
let result = try await req.feedbackKit.votes.unvote(
    feedbackId: feedbackId,
    request: CreateVoteRequest(userId: "user-123")
)
```

### Comments

```swift
// List comments
let comments = try await req.feedbackKit.comments.list(feedbackId: feedbackId)

// Add a comment
let comment = try await req.feedbackKit.comments.create(
    feedbackId: feedbackId,
    request: CreateCommentRequest(content: "Acknowledged by server", userId: "admin", isAdmin: true)
)
```

### SDK User Registration

```swift
// Register or update a user (with optional MRR tracking)
let user = try await req.feedbackKit.users.register(
    RegisterSDKUserRequest(userId: "user-123", mrr: 29.99)
)
```

### Event Tracking

```swift
// Track a custom event
let event = try await req.feedbackKit.events.track(
    TrackViewEventRequest(
        eventName: "api_request",
        userId: "user-123",
        properties: ["endpoint": "/checkout", "method": "POST"]
    )
)
```

## Admin Operations (Bearer Token)

These operations require a Bearer token from an authenticated admin user.

### Authentication

```swift
// Login
let auth = try await req.feedbackKitAdmin(token: "").auth.login(
    LoginRequest(email: "admin@example.com", password: "password")
)
let token = auth.token

// Use the token for subsequent admin calls
let admin = try req.feedbackKitAdmin(token: token)
let me = try await admin.auth.me()
```

### Projects

```swift
let admin = try req.feedbackKitAdmin(token: bearerToken)

// List projects
let projects = try await admin.projects.list()

// Create a project
let project = try await admin.projects.create(
    CreateProjectRequest(name: "My App", description: "User feedback for My App")
)

// Archive / unarchive
let archived = try await admin.projects.archive(id: projectId)
let restored = try await admin.projects.unarchive(id: projectId)

// Regenerate API key
let updated = try await admin.projects.regenerateKey(id: projectId)
```

### Members & Invites

```swift
let admin = try req.feedbackKitAdmin(token: bearerToken)

// Add a member
let response = try await admin.members.add(
    projectId: projectId,
    AddMemberRequest(email: "dev@example.com", role: .member)
)

// Update role
let member = try await admin.members.updateRole(
    projectId: projectId,
    memberId: memberId,
    UpdateMemberRoleRequest(role: .admin)
)

// List pending invites
let invites = try await admin.members.listInvites(projectId: projectId)
```

### Dashboard & Analytics

```swift
let admin = try req.feedbackKitAdmin(token: bearerToken)

// Home dashboard (all projects)
let dashboard = try await admin.dashboard.home()
print("Total feedback: \(dashboard.totalFeedback)")
print("Total MRR users: \(dashboard.totalUsers)")

// Project-specific stats
let stats = try await admin.dashboard.project(id: projectId)

// SDK user stats
let userStats = try await admin.users.stats(projectId: projectId)
print("Total MRR: $\(userStats.totalMRR)")

// Event stats (last 30 days)
let eventStats = try await admin.events.stats(projectId: projectId, days: 30)
```

### Feedback Management (Admin)

```swift
let admin = try req.feedbackKitAdmin(token: bearerToken)

// Update status
let updated = try await admin.feedback.update(
    id: feedbackId,
    UpdateFeedbackRequest(status: .inProgress)
)

// Reject with reason
let rejected = try await admin.feedback.update(
    id: feedbackId,
    UpdateFeedbackRequest(status: .rejected, rejectionReason: "Duplicate of #42")
)

// Merge feedback
let merged = try await admin.feedback.merge(
    MergeFeedbackRequest(
        primaryFeedbackId: primaryId,
        secondaryFeedbackIds: [duplicateId1, duplicateId2]
    )
)
```

### Subscriptions

```swift
let admin = try req.feedbackKitAdmin(token: bearerToken)

// Get current subscription
let sub = try await admin.subscriptions.get()
print("Tier: \(sub.tier), can create project: \(sub.limits.canCreateProject)")

// Create Stripe checkout
let checkout = try await admin.subscriptions.createCheckout(
    CreateCheckoutSessionRequest(priceId: "price_xxx", successUrl: "https://myapp.com/success")
)
// Redirect to checkout.checkoutUrl
```

### Integrations

All 10 integrations (GitHub, ClickUp, Notion, Monday, Linear, Trello, Airtable, Asana, Basecamp, Email Campaign) are accessible via `admin.integrations`:

```swift
let admin = try req.feedbackKitAdmin(token: bearerToken)

// Configure GitHub integration
let project = try await admin.integrations.github.updateSettings(
    projectId: projectId,
    UpdateGitHubSettingsRequest(
        githubOwner: "my-org",
        githubRepo: "my-repo",
        githubToken: "ghp_xxx",
        githubIsActive: true
    )
)

// Create a GitHub issue from feedback
let issue = try await admin.integrations.github.createIssue(
    projectId: projectId,
    CreateGitHubIssueRequest(feedbackId: feedbackId)
)
print("Created: \(issue.issueUrl)")

// Bulk create Linear issues
let result = try await admin.integrations.linear.bulkCreateIssues(
    projectId: projectId,
    BulkCreateLinearIssuesRequest(feedbackIds: [id1, id2, id3])
)
print("Created \(result.created.count), failed \(result.failed.count)")

// Browse ClickUp hierarchy for settings
let workspaces = try await admin.integrations.clickup.workspaces(projectId: projectId)
let spaces = try await admin.integrations.clickup.spaces(projectId: projectId, workspaceId: workspaces[0].id)
```

## Using Outside Request Context

You can also use FeedbackKit from `Application` directly (e.g., in lifecycle handlers or background jobs):

```swift
// SDK operations
let sdk = try app.feedbackKit.client()
let feedback = try await sdk.feedback.list()

// Admin operations
let admin = try app.feedbackKit.adminClient(token: savedToken)
let dashboard = try await admin.dashboard.home()
```

## Error Handling

All API methods throw `FeedbackKitError`, which conforms to Vapor's `AbortError`:

```swift
do {
    let feedback = try await req.feedbackKit.feedback.create(request)
} catch let error as FeedbackKitError {
    switch error {
    case .badRequest(let message):
        // Validation error
    case .paymentRequired(let message):
        // Tier limit exceeded (e.g., Free tier max 10 feedback)
    case .unauthorized, .invalidApiKey:
        // Auth failure
    case .conflict:
        // Duplicate (e.g., user already voted)
    case .notFound:
        // Resource not found
    default:
        // Server error
    }
}
```

## API Reference

### SDK Client (`req.feedbackKit`)

| Module | Methods |
|--------|---------|
| `feedback` | `list`, `get`, `create`, `delete` |
| `votes` | `vote`, `unvote` |
| `comments` | `list`, `create`, `delete` |
| `users` | `register` |
| `events` | `track` |

### Admin Client (`req.feedbackKitAdmin(token:)`)

| Module | Methods |
|--------|---------|
| `auth` | `signup`, `login`, `me`, `logout`, `verifyEmail`, `changePassword`, `forgotPassword`, `resetPassword`, `updateNotifications`, `subscription`, `syncSubscription` |
| `projects` | `list`, `get`, `create`, `update`, `delete`, `archive`, `unarchive`, `regenerateKey`, `transferOwnership`, `updateSlack`, `updateStatuses`, `updateEmailNotifyStatuses` |
| `members` | `list`, `add`, `updateRole`, `remove`, `listInvites`, `cancelInvite`, `resendInvite`, `acceptInvite`, `previewInvite` |
| `dashboard` | `home`, `project` |
| `subscriptions` | `get`, `createCheckout`, `portal`, `syncApple` |
| `devices` | `register`, `list`, `delete` |
| `feedback` | `update`, `delete`, `merge` |
| `users` | `list`, `stats`, `listAll`, `allStats` |
| `events` | `list`, `stats`, `allStats` |
| `integrations` | `.github`, `.clickup`, `.notion`, `.monday`, `.linear`, `.trello`, `.airtable`, `.asana`, `.basecamp`, `.emailCampaign` |

## License

MIT
