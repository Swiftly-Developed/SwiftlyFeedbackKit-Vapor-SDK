import Foundation
import Testing
import Vapor
@testable import SwiftlyFeedbackKitVapor

// MARK: - The census table

enum AuthSurface: Sendable {
    case apiKey
    case bearer
    case publicNoAuth
}

struct OpRow: Sendable {
    let family: String   // API source file base name (the completeness census key)
    let op: String       // function name as declared in source
    let label: String    // unique display label (disambiguates overloads)
    let method: HTTPMethod
    let path: String     // path after /api/v1, with fixture ids interpolated
    let surface: AuthSurface
    let invoke: @Sendable (FeedbackKitSDK, FeedbackKitAdmin) async throws -> Void
}

extension OpRow: CustomTestStringConvertible {
    var testDescription: String { "\(family).\(label) \(method) \(path)" }
}

/// One row per public operation — 129 today. Every row drives the REAL client
/// over the recorder and pins method, exact path, and auth surface.
enum OpCensus {
    static let a = Fixed.idA
    static let b = Fixed.idB

    static let sdkSurface: [OpRow] = [
        OpRow(family: "FeedbackAPI", op: "list", label: "list", method: .GET, path: "/feedbacks?paged=1", surface: .apiKey) { sdk, _ in
            _ = try await sdk.feedback.list()
        },
        OpRow(family: "FeedbackAPI", op: "get", label: "get", method: .GET, path: "/feedbacks/\(a)", surface: .apiKey) { sdk, _ in
            _ = try await sdk.feedback.get(id: a)
        },
        OpRow(family: "FeedbackAPI", op: "create", label: "create", method: .POST, path: "/feedbacks", surface: .apiKey) { sdk, _ in
            _ = try await sdk.feedback.create(CreateFeedbackRequest(
                title: "Add a dark theme", description: "The list is hard to read at night.",
                category: .featureRequest, userId: "fixture-end-user"))
        },
        // F3 (fixed 2026-08-15): `FeedbackAPI.delete(id:)` sent X-API-Key at a
        // Bearer-only route. It is now deprecated and throws before issuing any
        // request, so it has no row here — the -18 census asserts its behaviour
        // directly, and the completeness census below accounts for it by name.
        OpRow(family: "VoteAPI", op: "vote", label: "vote", method: .POST, path: "/feedbacks/\(a)/votes", surface: .apiKey) { sdk, _ in
            _ = try await sdk.votes.vote(feedbackId: a, request: CreateVoteRequest(userId: "fixture-end-user"))
        },
        OpRow(family: "VoteAPI", op: "unvote", label: "unvote", method: .DELETE, path: "/feedbacks/\(a)/votes", surface: .apiKey) { sdk, _ in
            _ = try await sdk.votes.unvote(feedbackId: a, request: CreateVoteRequest(userId: "fixture-end-user"))
        },
        OpRow(family: "CommentAPI", op: "list", label: "list", method: .GET, path: "/feedbacks/\(a)/comments?paged=1", surface: .apiKey) { sdk, _ in
            _ = try await sdk.comments.list(feedbackId: a)
        },
        OpRow(family: "CommentAPI", op: "create", label: "create", method: .POST, path: "/feedbacks/\(a)/comments", surface: .apiKey) { sdk, _ in
            _ = try await sdk.comments.create(feedbackId: a, request: CreateCommentRequest(content: "Please add dark mode.", userId: "fixture-end-user"))
        },
        OpRow(family: "CommentAPI", op: "delete", label: "delete", method: .DELETE, path: "/feedbacks/\(a)/comments/\(b)", surface: .apiKey) { sdk, _ in
            try await sdk.comments.delete(feedbackId: a, commentId: b, userId: "fixture-end-user")
        },
        OpRow(family: "SDKUserAPI", op: "register", label: "register", method: .POST, path: "/users/register", surface: .apiKey) { sdk, _ in
            _ = try await sdk.users.register(RegisterSDKUserRequest(userId: "fixture-end-user", mrr: 42.5))
        },
        OpRow(family: "EventAPI", op: "track", label: "track", method: .POST, path: "/events/track", surface: .apiKey) { sdk, _ in
            _ = try await sdk.events.track(TrackViewEventRequest(eventName: "feedback_list", userId: "fixture-end-user"))
        },
    ]

    static let authRows: [OpRow] = [
        OpRow(family: "AuthAPI", op: "signup", label: "signup", method: .POST, path: "/auth/signup", surface: .publicNoAuth) { _, admin in
            _ = try await admin.auth.signup(SignupRequest(email: "fixture-user@example.invalid", name: "Fixture User", password: "fixture-password"))
        },
        OpRow(family: "AuthAPI", op: "login", label: "login", method: .POST, path: "/auth/login", surface: .publicNoAuth) { _, admin in
            _ = try await admin.auth.login(LoginRequest(email: "fixture-user@example.invalid", password: "fixture-password"))
        },
        OpRow(family: "AuthAPI", op: "me", label: "me", method: .GET, path: "/auth/me", surface: .bearer) { _, admin in
            _ = try await admin.auth.me()
        },
        OpRow(family: "AuthAPI", op: "logout", label: "logout", method: .POST, path: "/auth/logout", surface: .bearer) { _, admin in
            try await admin.auth.logout()
        },
        OpRow(family: "AuthAPI", op: "verifyEmail", label: "verifyEmail", method: .POST, path: "/auth/verify-email", surface: .publicNoAuth) { _, admin in
            _ = try await admin.auth.verifyEmail(VerifyEmailRequest(code: "123456"))
        },
        OpRow(family: "AuthAPI", op: "resendVerification", label: "resendVerification", method: .POST, path: "/auth/resend-verification", surface: .bearer) { _, admin in
            _ = try await admin.auth.resendVerification()
        },
        OpRow(family: "AuthAPI", op: "changePassword", label: "changePassword", method: .PUT, path: "/auth/password", surface: .bearer) { _, admin in
            try await admin.auth.changePassword(ChangePasswordRequest(currentPassword: "fixture-password", newPassword: "fixture-password-2"))
        },
        OpRow(family: "AuthAPI", op: "deleteAccount", label: "deleteAccount", method: .DELETE, path: "/auth/account", surface: .bearer) { _, admin in
            try await admin.auth.deleteAccount(DeleteAccountRequest(password: "fixture-password"))
        },
        OpRow(family: "AuthAPI", op: "forgotPassword", label: "forgotPassword", method: .POST, path: "/auth/forgot-password", surface: .publicNoAuth) { _, admin in
            _ = try await admin.auth.forgotPassword(ForgotPasswordRequest(email: "fixture-user@example.invalid"))
        },
        OpRow(family: "AuthAPI", op: "resetPassword", label: "resetPassword", method: .POST, path: "/auth/reset-password", surface: .publicNoAuth) { _, admin in
            _ = try await admin.auth.resetPassword(ResetPasswordRequest(code: "123456", newPassword: "fixture-password-2"))
        },
        OpRow(family: "AuthAPI", op: "updateNotifications", label: "updateNotifications", method: .PATCH, path: "/auth/notifications", surface: .bearer) { _, admin in
            _ = try await admin.auth.updateNotifications(UpdateNotificationSettingsRequest(notifyNewFeedback: true))
        },
        OpRow(family: "AuthAPI", op: "subscription", label: "subscription", method: .GET, path: "/auth/subscription", surface: .bearer) { _, admin in
            _ = try await admin.auth.subscription()
        },
        OpRow(family: "AuthAPI", op: "syncSubscription", label: "syncSubscription", method: .POST, path: "/auth/subscription/sync", surface: .bearer) { _, admin in
            _ = try await admin.auth.syncSubscription()
        },
    ]

    static let projectRows: [OpRow] = [
        OpRow(family: "ProjectAPI", op: "list", label: "list", method: .GET, path: "/projects", surface: .bearer) { _, admin in
            _ = try await admin.projects.list()
        },
        OpRow(family: "ProjectAPI", op: "get", label: "get", method: .GET, path: "/projects/\(a)", surface: .bearer) { _, admin in
            _ = try await admin.projects.get(id: a)
        },
        OpRow(family: "ProjectAPI", op: "create", label: "create", method: .POST, path: "/projects", surface: .bearer) { _, admin in
            _ = try await admin.projects.create(CreateProjectRequest(name: "Fixture Project"))
        },
        OpRow(family: "ProjectAPI", op: "update", label: "update", method: .PATCH, path: "/projects/\(a)", surface: .bearer) { _, admin in
            _ = try await admin.projects.update(id: a, UpdateProjectRequest(name: "Fixture Project 2"))
        },
        OpRow(family: "ProjectAPI", op: "delete", label: "delete", method: .DELETE, path: "/projects/\(a)", surface: .bearer) { _, admin in
            try await admin.projects.delete(id: a)
        },
        OpRow(family: "ProjectAPI", op: "archive", label: "archive", method: .POST, path: "/projects/\(a)/archive", surface: .bearer) { _, admin in
            _ = try await admin.projects.archive(id: a)
        },
        OpRow(family: "ProjectAPI", op: "unarchive", label: "unarchive", method: .POST, path: "/projects/\(a)/unarchive", surface: .bearer) { _, admin in
            _ = try await admin.projects.unarchive(id: a)
        },
        OpRow(family: "ProjectAPI", op: "regenerateKey", label: "regenerateKey", method: .POST, path: "/projects/\(a)/regenerate-key", surface: .bearer) { _, admin in
            _ = try await admin.projects.regenerateKey(id: a)
        },
        OpRow(family: "ProjectAPI", op: "transferOwnership", label: "transferOwnership", method: .POST, path: "/projects/\(a)/transfer-ownership", surface: .bearer) { _, admin in
            _ = try await admin.projects.transferOwnership(id: a, TransferOwnershipRequest(newOwnerEmail: "fixture-user@example.invalid"))
        },
        OpRow(family: "ProjectAPI", op: "updateSlack", label: "updateSlack", method: .PATCH, path: "/projects/\(a)/slack", surface: .bearer) { _, admin in
            _ = try await admin.projects.updateSlack(projectId: a, UpdateSlackSettingsRequest(slackIsActive: false))
        },
        OpRow(family: "ProjectAPI", op: "updateStatuses", label: "updateStatuses", method: .PATCH, path: "/projects/\(a)/statuses", surface: .bearer) { _, admin in
            _ = try await admin.projects.updateStatuses(projectId: a, UpdateAllowedStatusesRequest(allowedStatuses: ["pending", "completed"]))
        },
        OpRow(family: "ProjectAPI", op: "updateEmailNotifyStatuses", label: "updateEmailNotifyStatuses", method: .PATCH, path: "/projects/\(a)/email-notify-statuses", surface: .bearer) { _, admin in
            _ = try await admin.projects.updateEmailNotifyStatuses(projectId: a, UpdateEmailNotifyStatusesRequest(emailNotifyStatuses: ["completed"]))
        },
    ]

    static let memberRows: [OpRow] = [
        OpRow(family: "MemberAPI", op: "list", label: "list", method: .GET, path: "/projects/\(a)/members", surface: .bearer) { _, admin in
            _ = try await admin.members.list(projectId: a)
        },
        OpRow(family: "MemberAPI", op: "add", label: "add", method: .POST, path: "/projects/\(a)/members", surface: .bearer) { _, admin in
            _ = try await admin.members.add(projectId: a, AddMemberRequest(email: "fixture-user@example.invalid", role: .member))
        },
        OpRow(family: "MemberAPI", op: "updateRole", label: "updateRole", method: .PATCH, path: "/projects/\(a)/members/\(b)", surface: .bearer) { _, admin in
            _ = try await admin.members.updateRole(projectId: a, memberId: b, UpdateMemberRoleRequest(role: .admin))
        },
        OpRow(family: "MemberAPI", op: "remove", label: "remove", method: .DELETE, path: "/projects/\(a)/members/\(b)", surface: .bearer) { _, admin in
            try await admin.members.remove(projectId: a, memberId: b)
        },
        OpRow(family: "MemberAPI", op: "listInvites", label: "listInvites", method: .GET, path: "/projects/\(a)/invites", surface: .bearer) { _, admin in
            _ = try await admin.members.listInvites(projectId: a)
        },
        OpRow(family: "MemberAPI", op: "cancelInvite", label: "cancelInvite", method: .DELETE, path: "/projects/\(a)/invites/\(b)", surface: .bearer) { _, admin in
            try await admin.members.cancelInvite(projectId: a, inviteId: b)
        },
        OpRow(family: "MemberAPI", op: "resendInvite", label: "resendInvite", method: .POST, path: "/projects/\(a)/invites/\(b)/resend", surface: .bearer) { _, admin in
            try await admin.members.resendInvite(projectId: a, inviteId: b)
        },
        OpRow(family: "MemberAPI", op: "acceptInvite", label: "acceptInvite", method: .POST, path: "/projects/invites/accept", surface: .bearer) { _, admin in
            _ = try await admin.members.acceptInvite(AcceptInviteRequest(code: "FIXTURECODE"))
        },
        OpRow(family: "MemberAPI", op: "previewInvite", label: "previewInvite", method: .GET, path: "/projects/invites/preview/FIXTURECODE", surface: .publicNoAuth) { _, admin in
            _ = try await admin.members.previewInvite(code: "FIXTURECODE")
        },
    ]

    static let dashboardDeviceSubscriptionRows: [OpRow] = [
        OpRow(family: "DashboardAPI", op: "home", label: "home", method: .GET, path: "/dashboard/home", surface: .bearer) { _, admin in
            _ = try await admin.dashboard.home()
        },
        OpRow(family: "DashboardAPI", op: "project", label: "project", method: .GET, path: "/dashboard/project/\(a)", surface: .bearer) { _, admin in
            _ = try await admin.dashboard.project(id: a)
        },
        OpRow(family: "SubscriptionAPI", op: "get", label: "get", method: .GET, path: "/subscriptions", surface: .bearer) { _, admin in
            _ = try await admin.subscriptions.get()
        },
        OpRow(family: "SubscriptionAPI", op: "createCheckout", label: "createCheckout", method: .POST, path: "/subscriptions/checkout", surface: .bearer) { _, admin in
            _ = try await admin.subscriptions.createCheckout(CreateCheckoutSessionRequest(priceId: "price_fixture"))
        },
        OpRow(family: "SubscriptionAPI", op: "portal", label: "portal", method: .GET, path: "/subscriptions/portal", surface: .bearer) { _, admin in
            _ = try await admin.subscriptions.portal()
        },
        OpRow(family: "SubscriptionAPI", op: "syncApple", label: "syncApple", method: .POST, path: "/subscriptions/sync-apple", surface: .bearer) { _, admin in
            _ = try await admin.subscriptions.syncApple(SyncAppleTransactionRequest(signedTransaction: "fixture-jws"))
        },
        OpRow(family: "DeviceAPI", op: "register", label: "register", method: .POST, path: "/devices/register", surface: .bearer) { _, admin in
            _ = try await admin.devices.register(RegisterDeviceRequest(token: "fixture-device-token", platform: "ios"))
        },
        OpRow(family: "DeviceAPI", op: "list", label: "list", method: .GET, path: "/devices", surface: .bearer) { _, admin in
            _ = try await admin.devices.list()
        },
        OpRow(family: "DeviceAPI", op: "delete", label: "delete(id:)", method: .DELETE, path: "/devices/\(a)", surface: .bearer) { _, admin in
            try await admin.devices.delete(id: a)
        },
        OpRow(family: "DeviceAPI", op: "delete", label: "delete(token:)", method: .DELETE, path: "/devices/token/fixture-device-token", surface: .bearer) { _, admin in
            try await admin.devices.delete(token: "fixture-device-token")
        },
    ]

    static let adminDataRows: [OpRow] = [
        OpRow(family: "AdminUserAPI", op: "list", label: "list", method: .GET, path: "/users/project/\(a)", surface: .bearer) { _, admin in
            _ = try await admin.users.list(projectId: a)
        },
        OpRow(family: "AdminUserAPI", op: "stats", label: "stats", method: .GET, path: "/users/project/\(a)/stats", surface: .bearer) { _, admin in
            _ = try await admin.users.stats(projectId: a)
        },
        OpRow(family: "AdminUserAPI", op: "listAll", label: "listAll", method: .GET, path: "/users/all", surface: .bearer) { _, admin in
            _ = try await admin.users.listAll()
        },
        OpRow(family: "AdminUserAPI", op: "allStats", label: "allStats", method: .GET, path: "/users/all/stats", surface: .bearer) { _, admin in
            _ = try await admin.users.allStats()
        },
        OpRow(family: "AdminEventAPI", op: "list", label: "list", method: .GET, path: "/events/project/\(a)", surface: .bearer) { _, admin in
            _ = try await admin.events.list(projectId: a)
        },
        OpRow(family: "AdminEventAPI", op: "stats", label: "stats", method: .GET, path: "/events/project/\(a)/stats", surface: .bearer) { _, admin in
            _ = try await admin.events.stats(projectId: a)
        },
        OpRow(family: "AdminEventAPI", op: "allStats", label: "allStats", method: .GET, path: "/events/all/stats", surface: .bearer) { _, admin in
            _ = try await admin.events.allStats()
        },
        OpRow(family: "AdminFeedbackAPI", op: "update", label: "update", method: .PATCH, path: "/feedbacks/\(a)", surface: .bearer) { _, admin in
            _ = try await admin.feedback.update(id: a, UpdateFeedbackRequest(status: .completed))
        },
        OpRow(family: "AdminFeedbackAPI", op: "delete", label: "delete", method: .DELETE, path: "/feedbacks/\(a)", surface: .bearer) { _, admin in
            try await admin.feedback.delete(id: a)
        },
        OpRow(family: "AdminFeedbackAPI", op: "merge", label: "merge", method: .POST, path: "/feedbacks/merge", surface: .bearer) { _, admin in
            _ = try await admin.feedback.merge(MergeFeedbackRequest(primaryFeedbackId: a, secondaryFeedbackIds: [b]))
        },
    ]

    static let integrationRowsA: [OpRow] = [
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "github.updateSettings", method: .PATCH, path: "/projects/\(a)/github", surface: .bearer) { _, admin in
            _ = try await admin.integrations.github.updateSettings(projectId: a, UpdateGitHubSettingsRequest(githubIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createIssue", label: "github.createIssue", method: .POST, path: "/projects/\(a)/github/issue", surface: .bearer) { _, admin in
            _ = try await admin.integrations.github.createIssue(projectId: a, CreateGitHubIssueRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateIssues", label: "github.bulkCreateIssues", method: .POST, path: "/projects/\(a)/github/issues", surface: .bearer) { _, admin in
            _ = try await admin.integrations.github.bulkCreateIssues(projectId: a, BulkCreateGitHubIssuesRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "clickup.updateSettings", method: .PATCH, path: "/projects/\(a)/clickup", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.updateSettings(projectId: a, UpdateClickUpSettingsRequest(clickupIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createTask", label: "clickup.createTask", method: .POST, path: "/projects/\(a)/clickup/task", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.createTask(projectId: a, CreateClickUpTaskRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateTasks", label: "clickup.bulkCreateTasks", method: .POST, path: "/projects/\(a)/clickup/tasks", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.bulkCreateTasks(projectId: a, BulkCreateClickUpTasksRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "workspaces", label: "clickup.workspaces", method: .GET, path: "/projects/\(a)/clickup/workspaces", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.workspaces(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "spaces", label: "clickup.spaces", method: .GET, path: "/projects/\(a)/clickup/spaces/ws1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.spaces(projectId: a, workspaceId: "ws1")
        },
        OpRow(family: "IntegrationAPI", op: "folders", label: "clickup.folders", method: .GET, path: "/projects/\(a)/clickup/folders/sp1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.folders(projectId: a, spaceId: "sp1")
        },
        OpRow(family: "IntegrationAPI", op: "lists", label: "clickup.lists", method: .GET, path: "/projects/\(a)/clickup/lists/fo1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.lists(projectId: a, folderId: "fo1")
        },
        OpRow(family: "IntegrationAPI", op: "folderlessLists", label: "clickup.folderlessLists", method: .GET, path: "/projects/\(a)/clickup/folderless-lists/sp1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.folderlessLists(projectId: a, spaceId: "sp1")
        },
        OpRow(family: "IntegrationAPI", op: "customFields", label: "clickup.customFields", method: .GET, path: "/projects/\(a)/clickup/custom-fields", surface: .bearer) { _, admin in
            _ = try await admin.integrations.clickup.customFields(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "notion.updateSettings", method: .PATCH, path: "/projects/\(a)/notion", surface: .bearer) { _, admin in
            _ = try await admin.integrations.notion.updateSettings(projectId: a, UpdateNotionSettingsRequest(notionIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createPage", label: "notion.createPage", method: .POST, path: "/projects/\(a)/notion/page", surface: .bearer) { _, admin in
            _ = try await admin.integrations.notion.createPage(projectId: a, CreateNotionPageRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreatePages", label: "notion.bulkCreatePages", method: .POST, path: "/projects/\(a)/notion/pages", surface: .bearer) { _, admin in
            _ = try await admin.integrations.notion.bulkCreatePages(projectId: a, BulkCreateNotionPagesRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "databases", label: "notion.databases", method: .GET, path: "/projects/\(a)/notion/databases", surface: .bearer) { _, admin in
            _ = try await admin.integrations.notion.databases(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "databaseProperties", label: "notion.databaseProperties", method: .GET, path: "/projects/\(a)/notion/database/db1/properties", surface: .bearer) { _, admin in
            _ = try await admin.integrations.notion.databaseProperties(projectId: a, databaseId: "db1")
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "monday.updateSettings", method: .PATCH, path: "/projects/\(a)/monday", surface: .bearer) { _, admin in
            _ = try await admin.integrations.monday.updateSettings(projectId: a, UpdateMondaySettingsRequest(mondayIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createItem", label: "monday.createItem", method: .POST, path: "/projects/\(a)/monday/item", surface: .bearer) { _, admin in
            _ = try await admin.integrations.monday.createItem(projectId: a, CreateMondayItemRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateItems", label: "monday.bulkCreateItems", method: .POST, path: "/projects/\(a)/monday/items", surface: .bearer) { _, admin in
            _ = try await admin.integrations.monday.bulkCreateItems(projectId: a, BulkCreateMondayItemsRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "boards", label: "monday.boards", method: .GET, path: "/projects/\(a)/monday/boards", surface: .bearer) { _, admin in
            _ = try await admin.integrations.monday.boards(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "groups", label: "monday.groups", method: .GET, path: "/projects/\(a)/monday/boards/bo1/groups", surface: .bearer) { _, admin in
            _ = try await admin.integrations.monday.groups(projectId: a, boardId: "bo1")
        },
        OpRow(family: "IntegrationAPI", op: "columns", label: "monday.columns", method: .GET, path: "/projects/\(a)/monday/boards/bo1/columns", surface: .bearer) { _, admin in
            _ = try await admin.integrations.monday.columns(projectId: a, boardId: "bo1")
        },
    ]

    static let integrationRowsB: [OpRow] = [
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "linear.updateSettings", method: .PATCH, path: "/projects/\(a)/linear", surface: .bearer) { _, admin in
            _ = try await admin.integrations.linear.updateSettings(projectId: a, UpdateLinearSettingsRequest(linearIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createIssue", label: "linear.createIssue", method: .POST, path: "/projects/\(a)/linear/issue", surface: .bearer) { _, admin in
            _ = try await admin.integrations.linear.createIssue(projectId: a, CreateLinearIssueRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateIssues", label: "linear.bulkCreateIssues", method: .POST, path: "/projects/\(a)/linear/issues", surface: .bearer) { _, admin in
            _ = try await admin.integrations.linear.bulkCreateIssues(projectId: a, BulkCreateLinearIssuesRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "teams", label: "linear.teams", method: .GET, path: "/projects/\(a)/linear/teams", surface: .bearer) { _, admin in
            _ = try await admin.integrations.linear.teams(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "projects", label: "linear.projects", method: .GET, path: "/projects/\(a)/linear/projects/te1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.linear.projects(projectId: a, teamId: "te1")
        },
        OpRow(family: "IntegrationAPI", op: "states", label: "linear.states", method: .GET, path: "/projects/\(a)/linear/states/te1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.linear.states(projectId: a, teamId: "te1")
        },
        OpRow(family: "IntegrationAPI", op: "labels", label: "linear.labels", method: .GET, path: "/projects/\(a)/linear/labels/te1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.linear.labels(projectId: a, teamId: "te1")
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "trello.updateSettings", method: .PATCH, path: "/projects/\(a)/trello", surface: .bearer) { _, admin in
            _ = try await admin.integrations.trello.updateSettings(projectId: a, UpdateTrelloSettingsRequest(trelloIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createCard", label: "trello.createCard", method: .POST, path: "/projects/\(a)/trello/card", surface: .bearer) { _, admin in
            _ = try await admin.integrations.trello.createCard(projectId: a, CreateTrelloCardRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateCards", label: "trello.bulkCreateCards", method: .POST, path: "/projects/\(a)/trello/cards", surface: .bearer) { _, admin in
            _ = try await admin.integrations.trello.bulkCreateCards(projectId: a, BulkCreateTrelloCardsRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "boards", label: "trello.boards", method: .GET, path: "/projects/\(a)/trello/boards", surface: .bearer) { _, admin in
            _ = try await admin.integrations.trello.boards(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "lists", label: "trello.lists", method: .GET, path: "/projects/\(a)/trello/boards/bo1/lists", surface: .bearer) { _, admin in
            _ = try await admin.integrations.trello.lists(projectId: a, boardId: "bo1")
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "airtable.updateSettings", method: .PATCH, path: "/projects/\(a)/airtable", surface: .bearer) { _, admin in
            _ = try await admin.integrations.airtable.updateSettings(projectId: a, UpdateAirtableSettingsRequest(airtableIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createRecord", label: "airtable.createRecord", method: .POST, path: "/projects/\(a)/airtable/record", surface: .bearer) { _, admin in
            _ = try await admin.integrations.airtable.createRecord(projectId: a, CreateAirtableRecordRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateRecords", label: "airtable.bulkCreateRecords", method: .POST, path: "/projects/\(a)/airtable/records", surface: .bearer) { _, admin in
            _ = try await admin.integrations.airtable.bulkCreateRecords(projectId: a, BulkCreateAirtableRecordsRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "bases", label: "airtable.bases", method: .GET, path: "/projects/\(a)/airtable/bases", surface: .bearer) { _, admin in
            _ = try await admin.integrations.airtable.bases(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "tables", label: "airtable.tables", method: .GET, path: "/projects/\(a)/airtable/tables/ba1", surface: .bearer) { _, admin in
            _ = try await admin.integrations.airtable.tables(projectId: a, baseId: "ba1")
        },
        OpRow(family: "IntegrationAPI", op: "fields", label: "airtable.fields", method: .GET, path: "/projects/\(a)/airtable/fields", surface: .bearer) { _, admin in
            _ = try await admin.integrations.airtable.fields(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "asana.updateSettings", method: .PATCH, path: "/projects/\(a)/asana", surface: .bearer) { _, admin in
            _ = try await admin.integrations.asana.updateSettings(projectId: a, UpdateAsanaSettingsRequest(asanaIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createTask", label: "asana.createTask", method: .POST, path: "/projects/\(a)/asana/task", surface: .bearer) { _, admin in
            _ = try await admin.integrations.asana.createTask(projectId: a, CreateAsanaTaskRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateTasks", label: "asana.bulkCreateTasks", method: .POST, path: "/projects/\(a)/asana/tasks", surface: .bearer) { _, admin in
            _ = try await admin.integrations.asana.bulkCreateTasks(projectId: a, BulkCreateAsanaTasksRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "workspaces", label: "asana.workspaces", method: .GET, path: "/projects/\(a)/asana/workspaces", surface: .bearer) { _, admin in
            _ = try await admin.integrations.asana.workspaces(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "projects", label: "asana.projects", method: .GET, path: "/projects/\(a)/asana/workspaces/ws1/projects", surface: .bearer) { _, admin in
            _ = try await admin.integrations.asana.projects(projectId: a, workspaceId: "ws1")
        },
        OpRow(family: "IntegrationAPI", op: "sections", label: "asana.sections", method: .GET, path: "/projects/\(a)/asana/projects/ap1/sections", surface: .bearer) { _, admin in
            _ = try await admin.integrations.asana.sections(projectId: a, asanaProjectId: "ap1")
        },
        OpRow(family: "IntegrationAPI", op: "customFields", label: "asana.customFields", method: .GET, path: "/projects/\(a)/asana/projects/ap1/custom-fields", surface: .bearer) { _, admin in
            _ = try await admin.integrations.asana.customFields(projectId: a, asanaProjectId: "ap1")
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "basecamp.updateSettings", method: .PATCH, path: "/projects/\(a)/basecamp", surface: .bearer) { _, admin in
            _ = try await admin.integrations.basecamp.updateSettings(projectId: a, UpdateBasecampSettingsRequest(basecampIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "createTodo", label: "basecamp.createTodo", method: .POST, path: "/projects/\(a)/basecamp/todo", surface: .bearer) { _, admin in
            _ = try await admin.integrations.basecamp.createTodo(projectId: a, CreateBasecampTodoRequest(feedbackId: b))
        },
        OpRow(family: "IntegrationAPI", op: "bulkCreateTodos", label: "basecamp.bulkCreateTodos", method: .POST, path: "/projects/\(a)/basecamp/todos", surface: .bearer) { _, admin in
            _ = try await admin.integrations.basecamp.bulkCreateTodos(projectId: a, BulkCreateBasecampTodosRequest(feedbackIds: [b]))
        },
        OpRow(family: "IntegrationAPI", op: "accounts", label: "basecamp.accounts", method: .GET, path: "/projects/\(a)/basecamp/accounts", surface: .bearer) { _, admin in
            _ = try await admin.integrations.basecamp.accounts(projectId: a)
        },
        OpRow(family: "IntegrationAPI", op: "projects", label: "basecamp.projects", method: .GET, path: "/projects/\(a)/basecamp/accounts/ac1/projects", surface: .bearer) { _, admin in
            _ = try await admin.integrations.basecamp.projects(projectId: a, accountId: "ac1")
        },
        OpRow(family: "IntegrationAPI", op: "todolists", label: "basecamp.todolists", method: .GET, path: "/projects/\(a)/basecamp/accounts/ac1/projects/bp1/todolists", surface: .bearer) { _, admin in
            _ = try await admin.integrations.basecamp.todolists(projectId: a, accountId: "ac1", basecampProjectId: "bp1")
        },
        OpRow(family: "IntegrationAPI", op: "updateSettings", label: "emailCampaign.updateSettings", method: .PATCH, path: "/projects/\(a)/email-campaign", surface: .bearer) { _, admin in
            _ = try await admin.integrations.emailCampaign.updateSettings(projectId: a, UpdateEmailCampaignSettingsRequest(emailCampaignIsActive: false))
        },
        OpRow(family: "IntegrationAPI", op: "lists", label: "emailCampaign.lists", method: .GET, path: "/projects/\(a)/email-campaign/lists", surface: .bearer) { _, admin in
            _ = try await admin.integrations.emailCampaign.lists(projectId: a)
        },
    ]

    /// METRICS03 phase 07 — the eight metrics operations, four per auth realm.
    ///
    /// Written from the contract table one row at a time, never by duplicating
    /// the row above: four of these differ from their twin only by the facade
    /// and the `/projects/:p` prefix, and a copy-paste that kept the wrong
    /// `surface:` would leave the one assertion that guards against a
    /// production 401 asserting the wrong thing while staying green.
    ///
    /// `measures` is required on all eight, so every recorded URL carries a
    /// query — which is why `normalizePath` below strips one.
    static let metricsRows: [OpRow] = [
        OpRow(family: "MetricsAPI", op: "summary", label: "summary", method: .GET,
              path: "/metrics/summary?measures=feedback_count", surface: .apiKey) { sdk, _ in
            _ = try await sdk.metrics.summary(measures: [.feedbackCount])
        },
        OpRow(family: "MetricsAPI", op: "timeseries", label: "timeseries", method: .GET,
              path: "/metrics/timeseries?measures=event_count&granularity=day", surface: .apiKey) { sdk, _ in
            _ = try await sdk.metrics.timeseries(measures: [.eventCount], granularity: .day)
        },
        OpRow(family: "MetricsAPI", op: "breakdown", label: "breakdown", method: .GET,
              path: "/metrics/breakdown?measures=feedback_count&dimension=status", surface: .apiKey) { sdk, _ in
            _ = try await sdk.metrics.breakdown(measures: [.feedbackCount], dimension: .status)
        },
        OpRow(family: "MetricsAPI", op: "events", label: "events", method: .GET,
              path: "/metrics/events?measures=event_count&page=2&per_page=50", surface: .apiKey) { sdk, _ in
            _ = try await sdk.metrics.events(measures: [.eventCount], page: 2, perPage: 50)
        },
        // The Bearer four. The comma-joined `measures` spelling is pinned here,
        // on two measures the key realm refuses outright.
        OpRow(family: "AdminMetricsAPI", op: "summary", label: "summary", method: .GET,
              path: "/projects/\(a)/metrics/summary?measures=mrr_sum,users_with_mrr", surface: .bearer) { _, admin in
            _ = try await admin.metrics.summary(projectId: a, measures: [.mrrSum, .usersWithMrr])
        },
        OpRow(family: "AdminMetricsAPI", op: "timeseries", label: "timeseries", method: .GET,
              path: "/projects/\(a)/metrics/timeseries?measures=feedback_count&granularity=week", surface: .bearer) { _, admin in
            _ = try await admin.metrics.timeseries(projectId: a, measures: [.feedbackCount], granularity: .week)
        },
        OpRow(family: "AdminMetricsAPI", op: "breakdown", label: "breakdown", method: .GET,
              path: "/projects/\(a)/metrics/breakdown?measures=feedback_count&dimension=category", surface: .bearer) { _, admin in
            _ = try await admin.metrics.breakdown(projectId: a, measures: [.feedbackCount], dimension: .category)
        },
        OpRow(family: "AdminMetricsAPI", op: "events", label: "events", method: .GET,
              path: "/projects/\(a)/metrics/events?measures=event_count&event_name=checkout_completed", surface: .bearer) { _, admin in
            _ = try await admin.metrics.events(projectId: a, measures: [.eventCount], eventName: "checkout_completed")
        },
    ]

    static let all: [OpRow] =
        sdkSurface + authRows + projectRows + memberRows +
        dashboardDeviceSubscriptionRows + adminDataRows +
        integrationRowsA + integrationRowsB + metricsRows
}

/// QA-UNIT12 Part D — -17 (the 121-operation method + path census) and
/// -18 (the auth-surface routing census).
@Suite("VaporSDK operation census")
struct VaporSDKOperationCensusSuite {

    // MARK: - -17: every public operation, invoked once against the recorder;
    // method, exact path and auth surface pinned. Today zero of the 121 had ever
    // been executed by anything.

    @Test(arguments: OpCensus.all)
    func operation(_ row: OpRow) async throws {
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        let admin = makeAdmin(stub: stub)

        // The default scripted response is 200 with an empty body: enough for the
        // request to be fully built and recorded. Decode failures are irrelevant
        // to this census and swallowed.
        _ = try? await row.invoke(sdk, admin)

        let requests = stub.requests
        #expect(requests.count == 1, "\(row.testDescription) issued \(requests.count) requests")
        let request = try #require(requests.first)
        #expect(request.method == row.method)
        #expect(request.url.string == Fixed.apiBase + row.path)

        switch row.surface {
        case .apiKey:
            #expect(request.headers.first(name: "X-API-Key") == Fixed.apiKey)
            #expect(request.headers.bearerAuthorization == nil, "C7: X-API-Key operations must not carry Bearer")
        case .bearer:
            #expect(request.headers.bearerAuthorization?.token == Fixed.bearerToken)
            #expect(request.headers.first(name: "X-API-Key") == nil, "C7: Bearer operations must not carry X-API-Key")
        case .publicNoAuth:
            #expect(request.headers.bearerAuthorization == nil)
            #expect(request.headers.first(name: "X-API-Key") == nil)
        }
    }

    // MARK: - Completeness: the census table covers every `public func` under
    // `API/` — as a multiset per family, so an overload or a new operation
    // cannot hide (a presence oracle cannot see an extra).

    @Test func censusCoversEveryPublicOperation() throws {
        let funcPattern = try NSRegularExpression(pattern: #"public func ([A-Za-z_][A-Za-z0-9_]*)\s*\("#)
        var declared: [String] = []
        for file in try PackagePaths.swiftFiles(under: PackagePaths.apiDir) {
            let family = file.deletingPathExtension().lastPathComponent
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in funcPattern.matches(in: text, range: range) {
                guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
                declared.append("\(family).\(text[nameRange])")
            }
        }
        // `FeedbackAPI.delete` is deprecated and throws before issuing any
        // request (F3, fixed 2026-08-15), so it cannot be driven through the
        // recorder table; -18 asserts its behaviour directly. It is appended by
        // name so this census still sees all 121 declared public operations.
        let tabled = OpCensus.all.map { "\($0.family).\($0.op)" } + ["FeedbackAPI.delete"]
        #expect(declared.count == 129, "the measured operation count moved: \(declared.count)")
        #expect(declared.sorted() == tabled.sorted(),
                "census drift — declared but not tabled: \(Set(declared).subtracting(tabled).sorted()); tabled but not declared: \(Set(tabled).subtracting(declared).sorted())")
    }

    // MARK: - -18: the auth-surface routing census — was RED ON ARRIVAL (F3),
    // fixed 2026-08-15.
    //
    // Every operation that sends X-API-Key must target a route the server
    // registers under `ApiKeyProjectResolver`. The route list below was derived
    // on 2026-08-15 from the server tree's controllers (`FeedbackController`,
    // `VoteController`, `CommentController`, `SDKUserController`,
    // `ViewEventController` — each `boot()`'s `ApiKeyProjectResolver` group).
    // `FeedbackAPI.delete(id:)` sent X-API-Key at `DELETE /feedbacks/:id`,
    // which the server registers ONLY behind Bearer auth — the operation could
    // never succeed. The fix (the user's decision: deprecate in the SDK, no new
    // server route) is asserted in the second half: the deprecated method
    // throws `.operationNotSupported` immediately and issues NO request —
    // no misleading 401 round-trip. `AdminFeedbackAPI.delete(id:)` is the
    // working spelling.

    @Test func apiKeyOperationsTargetApiKeyRoutes() async {
        let apiKeyRoutes: Set<String> = [
            "GET /feedbacks",
            "POST /feedbacks",
            "GET /feedbacks/:p",
            "POST /feedbacks/:p/votes",
            "DELETE /feedbacks/:p/votes",
            "GET /feedbacks/:p/comments",
            "POST /feedbacks/:p/comments",
            "DELETE /feedbacks/:p/comments/:p",
            "POST /users/register",
            "POST /events/track",
            // METRICS03 phase 07 — the key realm's four metrics routes.
            "GET /metrics/summary",
            "GET /metrics/timeseries",
            "GET /metrics/breakdown",
            "GET /metrics/events",
        ]
        var violations: [String] = []
        for row in OpCensus.all where row.surface == .apiKey {
            let normalized = normalizePath(row.path)
            let key = "\(row.method) \(normalized)"
            if !apiKeyRoutes.contains(key) {
                violations.append("\(row.family).\(row.label) sends X-API-Key at '\(key)', which the server does not register under ApiKeyProjectResolver")
            }
        }
        #expect(violations.isEmpty, "\(violations)")

        // The F3 fix's contract: deprecated, throws before the transport, and
        // the recorder must stay empty. (The deprecation warning on this call
        // is the point — the test exercises the deprecated stub deliberately.)
        let stub = StubClient()
        let sdk = makeSDK(stub: stub)
        do {
            try await sdk.feedback.delete(id: Fixed.idA)
            Issue.record("the deprecated FeedbackAPI.delete(id:) must throw")
        } catch let error as FeedbackKitError {
            #expect(caseName(error) == "operationNotSupported")
            #expect(error.reason.contains("Bearer"), "the error must say WHY: Bearer-only route")
        } catch {
            Issue.record("expected FeedbackKitError.operationNotSupported, got \(error)")
        }
        #expect(stub.requests.isEmpty, "the doomed X-API-Key request must not be issued at all")
    }

    // MARK: - The query-drop in `normalizePath` really is a no-op for every
    // operation that predates METRICS03 phase 07.
    //
    // The claim "it changes nothing for the shipped rows" is cheap to assert
    // and worthless unless measured, because the function it changes is the
    // one deciding whether -18 accepts a route at all. Set equality against
    // the ten route keys the server registers under `ApiKeyProjectResolver`,
    // so a normaliser that mangled a key would have to mangle it INTO another
    // shipped key to survive.

    @Test func normalizePathIsANoOpForTheShippedApiKeyRoutes() {
        let shippedTen: Set<String> = [
            "GET /feedbacks",
            "POST /feedbacks",
            "GET /feedbacks/:p",
            "POST /feedbacks/:p/votes",
            "DELETE /feedbacks/:p/votes",
            "GET /feedbacks/:p/comments",
            "POST /feedbacks/:p/comments",
            "DELETE /feedbacks/:p/comments/:p",
            "POST /users/register",
            "POST /events/track",
        ]
        let preExisting = OpCensus.all.filter { $0.surface == .apiKey && $0.family != "MetricsAPI" }
        #expect(preExisting.count == 10, "expected the ten pre-metrics X-API-Key rows, saw \(preExisting.count)")
        let derived = Set(preExisting.map { "\($0.method) \(normalizePath($0.path))" })
        #expect(derived == shippedTen,
                "normalizePath moved a shipped route key — derived but not shipped: \(derived.subtracting(shippedTen).sorted()); shipped but not derived: \(shippedTen.subtracting(derived).sorted())")

        // And it does what phase 07 needs: a query-carrying URL normalises to
        // its route, not to a route-with-a-query.
        let metricsKeys = Set(OpCensus.metricsRows.filter { $0.surface == .apiKey }
            .map { "\($0.method) \(normalizePath($0.path))" })
        #expect(metricsKeys == [
            "GET /metrics/summary",
            "GET /metrics/timeseries",
            "GET /metrics/breakdown",
            "GET /metrics/events",
        ], "metrics route keys: \(metricsKeys.sorted())")
    }

    /// Derives a ROUTE from a recorded URL suffix: drops the query, then
    /// replaces UUID-shaped path segments with `:p`.
    ///
    /// The query drop arrived with METRICS03 phase 07, whose eight rows all
    /// carry a required `measures` parameter. It is a no-op for every row that
    /// predates it — none carried a query — and
    /// `normalizePathIsANoOpForTheShippedApiKeyRoutes` measures that rather
    /// than asserting it.
    private func normalizePath(_ path: String) -> String {
        let routePart = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
        return "/" + routePart.split(separator: "/").map { segment in
            UUID(uuidString: String(segment)) != nil ? ":p" : String(segment)
        }.joined(separator: "/")
    }
}

extension AuthSurface: Equatable {}
