import Vapor
import SwiftlyFeedbackKitVapor

// The functions in this file are the Swift samples in README.md,
// docs/getting-started.md, and the website page docs/vapor.leaf.
// `swift build` in Examples/GettingStarted type-checks them against this
// checkout. Nothing here performs a network call.

@main
enum GettingStarted {
    static func main() {}
}

func configureFeedbackKit(_ app: Application) {
    app.feedbackKit.configure(
        apiKey: Environment.get("FEEDBACKKIT_API_KEY") ?? "",
        environment: .production
    )
}

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

func registerSDKUser(_ req: Request) async throws {
    let user = try await req.feedbackKit.users.register(
        RegisterSDKUserRequest(userId: "user-123", mrr: 29.99)
    )
    _ = user
}

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

func readSyncStates(_ req: Request) async throws {
    let feedbackId = UUID()
    let item = try await req.feedbackKit.feedback.get(id: feedbackId, userId: "user-123")
    for state in item.syncStates ?? [] {
        let ref = state.providerRefUrl ?? ""
        print(state.provider, state.state, ref)
    }
}

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

func metricsFreePlan(_ summary: MetricSummary) {
    if summary.meta.resolvedEventScope == .predefinedOnly {
        _ = summary.meta.eventScope
    }
}

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

func outsideRequestContext(_ app: Application) async throws {
    let savedToken = "token"
    let sdk = try app.feedbackKit.client()
    let feedback = try await sdk.feedback.list()
    let admin = try app.feedbackKit.adminClient(token: savedToken)
    let dashboard = try await admin.dashboard.home()
    _ = (feedback, dashboard)
}

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
