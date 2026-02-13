import Vapor

/// Integration settings and operations using Bearer token authentication.
public struct IntegrationAPI: Sendable {
    let client: FeedbackKitClient
    let token: String

    public var github: GitHubIntegration { GitHubIntegration(client: client, token: token) }
    public var clickup: ClickUpIntegration { ClickUpIntegration(client: client, token: token) }
    public var notion: NotionIntegration { NotionIntegration(client: client, token: token) }
    public var monday: MondayIntegration { MondayIntegration(client: client, token: token) }
    public var linear: LinearIntegration { LinearIntegration(client: client, token: token) }
    public var trello: TrelloIntegration { TrelloIntegration(client: client, token: token) }
    public var airtable: AirtableIntegration { AirtableIntegration(client: client, token: token) }
    public var asana: AsanaIntegration { AsanaIntegration(client: client, token: token) }
    public var basecamp: BasecampIntegration { BasecampIntegration(client: client, token: token) }
    public var emailCampaign: EmailCampaignIntegration { EmailCampaignIntegration(client: client, token: token) }
}

// MARK: - GitHub

public struct GitHubIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateGitHubSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/github", body: request, token: token)
    }
    public func createIssue(projectId: UUID, _ request: CreateGitHubIssueRequest) async throws -> CreateGitHubIssueResponse {
        try await client.adminPost(path: "/projects/\(projectId)/github/issue", body: request, token: token)
    }
    public func bulkCreateIssues(projectId: UUID, _ request: BulkCreateGitHubIssuesRequest) async throws -> BulkCreateGitHubIssuesResponse {
        try await client.adminPost(path: "/projects/\(projectId)/github/issues", body: request, token: token)
    }
}

// MARK: - ClickUp

public struct ClickUpIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateClickUpSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/clickup", body: request, token: token)
    }
    public func createTask(projectId: UUID, _ request: CreateClickUpTaskRequest) async throws -> CreateClickUpTaskResponse {
        try await client.adminPost(path: "/projects/\(projectId)/clickup/task", body: request, token: token)
    }
    public func bulkCreateTasks(projectId: UUID, _ request: BulkCreateClickUpTasksRequest) async throws -> BulkCreateClickUpTasksResponse {
        try await client.adminPost(path: "/projects/\(projectId)/clickup/tasks", body: request, token: token)
    }
    public func workspaces(projectId: UUID) async throws -> [ClickUpWorkspace] {
        try await client.adminGet(path: "/projects/\(projectId)/clickup/workspaces", token: token)
    }
    public func spaces(projectId: UUID, workspaceId: String) async throws -> [ClickUpSpace] {
        try await client.adminGet(path: "/projects/\(projectId)/clickup/spaces/\(workspaceId)", token: token)
    }
    public func folders(projectId: UUID, spaceId: String) async throws -> [ClickUpFolder] {
        try await client.adminGet(path: "/projects/\(projectId)/clickup/folders/\(spaceId)", token: token)
    }
    public func lists(projectId: UUID, folderId: String) async throws -> [ClickUpList] {
        try await client.adminGet(path: "/projects/\(projectId)/clickup/lists/\(folderId)", token: token)
    }
    public func folderlessLists(projectId: UUID, spaceId: String) async throws -> [ClickUpList] {
        try await client.adminGet(path: "/projects/\(projectId)/clickup/folderless-lists/\(spaceId)", token: token)
    }
    public func customFields(projectId: UUID) async throws -> [ClickUpCustomField] {
        try await client.adminGet(path: "/projects/\(projectId)/clickup/custom-fields", token: token)
    }
}

// MARK: - Notion

public struct NotionIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateNotionSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/notion", body: request, token: token)
    }
    public func createPage(projectId: UUID, _ request: CreateNotionPageRequest) async throws -> CreateNotionPageResponse {
        try await client.adminPost(path: "/projects/\(projectId)/notion/page", body: request, token: token)
    }
    public func bulkCreatePages(projectId: UUID, _ request: BulkCreateNotionPagesRequest) async throws -> BulkCreateNotionPagesResponse {
        try await client.adminPost(path: "/projects/\(projectId)/notion/pages", body: request, token: token)
    }
    public func databases(projectId: UUID) async throws -> [NotionDatabase] {
        try await client.adminGet(path: "/projects/\(projectId)/notion/databases", token: token)
    }
    public func databaseProperties(projectId: UUID, databaseId: String) async throws -> [NotionProperty] {
        try await client.adminGet(path: "/projects/\(projectId)/notion/database/\(databaseId)/properties", token: token)
    }
}

// MARK: - Monday

public struct MondayIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateMondaySettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/monday", body: request, token: token)
    }
    public func createItem(projectId: UUID, _ request: CreateMondayItemRequest) async throws -> CreateMondayItemResponse {
        try await client.adminPost(path: "/projects/\(projectId)/monday/item", body: request, token: token)
    }
    public func bulkCreateItems(projectId: UUID, _ request: BulkCreateMondayItemsRequest) async throws -> BulkCreateMondayItemsResponse {
        try await client.adminPost(path: "/projects/\(projectId)/monday/items", body: request, token: token)
    }
    public func boards(projectId: UUID) async throws -> [MondayBoard] {
        try await client.adminGet(path: "/projects/\(projectId)/monday/boards", token: token)
    }
    public func groups(projectId: UUID, boardId: String) async throws -> [MondayGroup] {
        try await client.adminGet(path: "/projects/\(projectId)/monday/boards/\(boardId)/groups", token: token)
    }
    public func columns(projectId: UUID, boardId: String) async throws -> [MondayColumn] {
        try await client.adminGet(path: "/projects/\(projectId)/monday/boards/\(boardId)/columns", token: token)
    }
}

// MARK: - Linear

public struct LinearIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateLinearSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/linear", body: request, token: token)
    }
    public func createIssue(projectId: UUID, _ request: CreateLinearIssueRequest) async throws -> CreateLinearIssueResponse {
        try await client.adminPost(path: "/projects/\(projectId)/linear/issue", body: request, token: token)
    }
    public func bulkCreateIssues(projectId: UUID, _ request: BulkCreateLinearIssuesRequest) async throws -> BulkCreateLinearIssuesResponse {
        try await client.adminPost(path: "/projects/\(projectId)/linear/issues", body: request, token: token)
    }
    public func teams(projectId: UUID) async throws -> [LinearTeam] {
        try await client.adminGet(path: "/projects/\(projectId)/linear/teams", token: token)
    }
    public func projects(projectId: UUID, teamId: String) async throws -> [LinearProject] {
        try await client.adminGet(path: "/projects/\(projectId)/linear/projects/\(teamId)", token: token)
    }
    public func states(projectId: UUID, teamId: String) async throws -> [LinearWorkflowState] {
        try await client.adminGet(path: "/projects/\(projectId)/linear/states/\(teamId)", token: token)
    }
    public func labels(projectId: UUID, teamId: String) async throws -> [LinearLabel] {
        try await client.adminGet(path: "/projects/\(projectId)/linear/labels/\(teamId)", token: token)
    }
}

// MARK: - Trello

public struct TrelloIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateTrelloSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/trello", body: request, token: token)
    }
    public func createCard(projectId: UUID, _ request: CreateTrelloCardRequest) async throws -> CreateTrelloCardResponse {
        try await client.adminPost(path: "/projects/\(projectId)/trello/card", body: request, token: token)
    }
    public func bulkCreateCards(projectId: UUID, _ request: BulkCreateTrelloCardsRequest) async throws -> BulkCreateTrelloCardsResponse {
        try await client.adminPost(path: "/projects/\(projectId)/trello/cards", body: request, token: token)
    }
    public func boards(projectId: UUID) async throws -> [TrelloBoard] {
        try await client.adminGet(path: "/projects/\(projectId)/trello/boards", token: token)
    }
    public func lists(projectId: UUID, boardId: String) async throws -> [TrelloList] {
        try await client.adminGet(path: "/projects/\(projectId)/trello/boards/\(boardId)/lists", token: token)
    }
}

// MARK: - Airtable

public struct AirtableIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateAirtableSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/airtable", body: request, token: token)
    }
    public func createRecord(projectId: UUID, _ request: CreateAirtableRecordRequest) async throws -> CreateAirtableRecordResponse {
        try await client.adminPost(path: "/projects/\(projectId)/airtable/record", body: request, token: token)
    }
    public func bulkCreateRecords(projectId: UUID, _ request: BulkCreateAirtableRecordsRequest) async throws -> BulkCreateAirtableRecordsResponse {
        try await client.adminPost(path: "/projects/\(projectId)/airtable/records", body: request, token: token)
    }
    public func bases(projectId: UUID) async throws -> [AirtableBase] {
        try await client.adminGet(path: "/projects/\(projectId)/airtable/bases", token: token)
    }
    public func tables(projectId: UUID, baseId: String) async throws -> [AirtableTable] {
        try await client.adminGet(path: "/projects/\(projectId)/airtable/tables/\(baseId)", token: token)
    }
    public func fields(projectId: UUID) async throws -> [AirtableField] {
        try await client.adminGet(path: "/projects/\(projectId)/airtable/fields", token: token)
    }
}

// MARK: - Asana

public struct AsanaIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateAsanaSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/asana", body: request, token: token)
    }
    public func createTask(projectId: UUID, _ request: CreateAsanaTaskRequest) async throws -> CreateAsanaTaskResponse {
        try await client.adminPost(path: "/projects/\(projectId)/asana/task", body: request, token: token)
    }
    public func bulkCreateTasks(projectId: UUID, _ request: BulkCreateAsanaTasksRequest) async throws -> BulkCreateAsanaTasksResponse {
        try await client.adminPost(path: "/projects/\(projectId)/asana/tasks", body: request, token: token)
    }
    public func workspaces(projectId: UUID) async throws -> [AsanaWorkspace] {
        try await client.adminGet(path: "/projects/\(projectId)/asana/workspaces", token: token)
    }
    public func projects(projectId: UUID, workspaceId: String) async throws -> [AsanaProject] {
        try await client.adminGet(path: "/projects/\(projectId)/asana/workspaces/\(workspaceId)/projects", token: token)
    }
    public func sections(projectId: UUID, asanaProjectId: String) async throws -> [AsanaSection] {
        try await client.adminGet(path: "/projects/\(projectId)/asana/projects/\(asanaProjectId)/sections", token: token)
    }
    public func customFields(projectId: UUID, asanaProjectId: String) async throws -> [AsanaCustomField] {
        try await client.adminGet(path: "/projects/\(projectId)/asana/projects/\(asanaProjectId)/custom-fields", token: token)
    }
}

// MARK: - Basecamp

public struct BasecampIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateBasecampSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/basecamp", body: request, token: token)
    }
    public func createTodo(projectId: UUID, _ request: CreateBasecampTodoRequest) async throws -> CreateBasecampTodoResponse {
        try await client.adminPost(path: "/projects/\(projectId)/basecamp/todo", body: request, token: token)
    }
    public func bulkCreateTodos(projectId: UUID, _ request: BulkCreateBasecampTodosRequest) async throws -> BulkCreateBasecampTodosResponse {
        try await client.adminPost(path: "/projects/\(projectId)/basecamp/todos", body: request, token: token)
    }
    public func accounts(projectId: UUID) async throws -> [BasecampAccount] {
        try await client.adminGet(path: "/projects/\(projectId)/basecamp/accounts", token: token)
    }
    public func projects(projectId: UUID, accountId: String) async throws -> [BasecampProject] {
        try await client.adminGet(path: "/projects/\(projectId)/basecamp/accounts/\(accountId)/projects", token: token)
    }
    public func todolists(projectId: UUID, accountId: String, basecampProjectId: String) async throws -> [BasecampTodolist] {
        try await client.adminGet(path: "/projects/\(projectId)/basecamp/accounts/\(accountId)/projects/\(basecampProjectId)/todolists", token: token)
    }
}

// MARK: - Email Campaign

public struct EmailCampaignIntegration: Sendable {
    let client: FeedbackKitClient; let token: String

    public func updateSettings(projectId: UUID, _ request: UpdateEmailCampaignSettingsRequest) async throws -> ProjectResponse {
        try await client.adminPatch(path: "/projects/\(projectId)/email-campaign", body: request, token: token)
    }
    public func lists(projectId: UUID) async throws -> [EmailCampaignList] {
        try await client.adminGet(path: "/projects/\(projectId)/email-campaign/lists", token: token)
    }
}
