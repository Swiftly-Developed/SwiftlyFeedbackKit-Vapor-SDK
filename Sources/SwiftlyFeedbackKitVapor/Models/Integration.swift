import Vapor

// MARK: - GitHub

public struct UpdateGitHubSettingsRequest: Content, Sendable {
    public var githubOwner: String?
    public var githubRepo: String?
    public var githubToken: String?
    public var githubDefaultLabels: [String]?
    public var githubSyncStatus: Bool?
    public var githubIsActive: Bool?

    public init(githubOwner: String? = nil, githubRepo: String? = nil, githubToken: String? = nil, githubDefaultLabels: [String]? = nil, githubSyncStatus: Bool? = nil, githubIsActive: Bool? = nil) {
        self.githubOwner = githubOwner; self.githubRepo = githubRepo; self.githubToken = githubToken
        self.githubDefaultLabels = githubDefaultLabels; self.githubSyncStatus = githubSyncStatus; self.githubIsActive = githubIsActive
    }
}

public struct CreateGitHubIssueRequest: Content, Sendable {
    public var feedbackId: UUID
    public var additionalLabels: [String]?
    public init(feedbackId: UUID, additionalLabels: [String]? = nil) { self.feedbackId = feedbackId; self.additionalLabels = additionalLabels }
}

public struct CreateGitHubIssueResponse: Content, Sendable {
    public var feedbackId: UUID
    public var issueUrl: String
    public var issueNumber: Int
}

public struct BulkCreateGitHubIssuesRequest: Content, Sendable {
    public var feedbackIds: [UUID]
    public var additionalLabels: [String]?
    public init(feedbackIds: [UUID], additionalLabels: [String]? = nil) { self.feedbackIds = feedbackIds; self.additionalLabels = additionalLabels }
}

public struct BulkCreateGitHubIssuesResponse: Content, Sendable {
    public var created: [CreateGitHubIssueResponse]
    public var failed: [UUID]
}

// MARK: - ClickUp

public struct UpdateClickUpSettingsRequest: Content, Sendable {
    public var clickupToken: String?
    public var clickupListId: String?
    public var clickupWorkspaceName: String?
    public var clickupListName: String?
    public var clickupDefaultTags: [String]?
    public var clickupSyncStatus: Bool?
    public var clickupSyncComments: Bool?
    public var clickupVotesFieldId: String?
    public var clickupIsActive: Bool?
    public init(clickupToken: String? = nil, clickupListId: String? = nil, clickupWorkspaceName: String? = nil, clickupListName: String? = nil, clickupDefaultTags: [String]? = nil, clickupSyncStatus: Bool? = nil, clickupSyncComments: Bool? = nil, clickupVotesFieldId: String? = nil, clickupIsActive: Bool? = nil) {
        self.clickupToken = clickupToken; self.clickupListId = clickupListId; self.clickupWorkspaceName = clickupWorkspaceName; self.clickupListName = clickupListName; self.clickupDefaultTags = clickupDefaultTags; self.clickupSyncStatus = clickupSyncStatus; self.clickupSyncComments = clickupSyncComments; self.clickupVotesFieldId = clickupVotesFieldId; self.clickupIsActive = clickupIsActive
    }
}

public struct CreateClickUpTaskRequest: Content, Sendable {
    public var feedbackId: UUID
    public var additionalTags: [String]?
    public init(feedbackId: UUID, additionalTags: [String]? = nil) { self.feedbackId = feedbackId; self.additionalTags = additionalTags }
}

public struct CreateClickUpTaskResponse: Content, Sendable { public var feedbackId: UUID; public var taskUrl: String; public var taskId: String }
public struct BulkCreateClickUpTasksRequest: Content, Sendable { public var feedbackIds: [UUID]; public var additionalTags: [String]?; public init(feedbackIds: [UUID], additionalTags: [String]? = nil) { self.feedbackIds = feedbackIds; self.additionalTags = additionalTags } }
public struct BulkCreateClickUpTasksResponse: Content, Sendable { public var created: [CreateClickUpTaskResponse]; public var failed: [UUID] }

// ClickUp hierarchy
public struct ClickUpWorkspace: Content, Sendable { public var id: String; public var name: String }
public struct ClickUpSpace: Content, Sendable { public var id: String; public var name: String }
public struct ClickUpFolder: Content, Sendable { public var id: String; public var name: String }
public struct ClickUpList: Content, Sendable { public var id: String; public var name: String }
public struct ClickUpCustomField: Content, Sendable { public var id: String; public var name: String; public var type: String }

// MARK: - Notion

public struct UpdateNotionSettingsRequest: Content, Sendable {
    public var notionToken: String?
    public var notionDatabaseId: String?
    public var notionDatabaseName: String?
    public var notionSyncStatus: Bool?
    public var notionSyncComments: Bool?
    public var notionStatusProperty: String?
    public var notionVotesProperty: String?
    public var notionIsActive: Bool?
    public init(notionToken: String? = nil, notionDatabaseId: String? = nil, notionDatabaseName: String? = nil, notionSyncStatus: Bool? = nil, notionSyncComments: Bool? = nil, notionStatusProperty: String? = nil, notionVotesProperty: String? = nil, notionIsActive: Bool? = nil) {
        self.notionToken = notionToken; self.notionDatabaseId = notionDatabaseId; self.notionDatabaseName = notionDatabaseName; self.notionSyncStatus = notionSyncStatus; self.notionSyncComments = notionSyncComments; self.notionStatusProperty = notionStatusProperty; self.notionVotesProperty = notionVotesProperty; self.notionIsActive = notionIsActive
    }
}

public struct CreateNotionPageRequest: Content, Sendable { public var feedbackId: UUID; public init(feedbackId: UUID) { self.feedbackId = feedbackId } }
public struct CreateNotionPageResponse: Content, Sendable { public var feedbackId: UUID; public var pageUrl: String; public var pageId: String }
public struct BulkCreateNotionPagesRequest: Content, Sendable { public var feedbackIds: [UUID]; public init(feedbackIds: [UUID]) { self.feedbackIds = feedbackIds } }
public struct BulkCreateNotionPagesResponse: Content, Sendable { public var created: [CreateNotionPageResponse]; public var failed: [UUID] }
public struct NotionDatabase: Content, Sendable { public var id: String; public var name: String; public var properties: [NotionProperty] }
public struct NotionProperty: Content, Sendable { public var id: String; public var name: String; public var type: String }

// MARK: - Monday

public struct UpdateMondaySettingsRequest: Content, Sendable {
    public var mondayToken: String?; public var mondayBoardId: String?; public var mondayBoardName: String?; public var mondayGroupId: String?; public var mondayGroupName: String?; public var mondaySyncStatus: Bool?; public var mondaySyncComments: Bool?; public var mondayStatusColumnId: String?; public var mondayVotesColumnId: String?; public var mondayIsActive: Bool?
    public init(mondayToken: String? = nil, mondayBoardId: String? = nil, mondayBoardName: String? = nil, mondayGroupId: String? = nil, mondayGroupName: String? = nil, mondaySyncStatus: Bool? = nil, mondaySyncComments: Bool? = nil, mondayStatusColumnId: String? = nil, mondayVotesColumnId: String? = nil, mondayIsActive: Bool? = nil) {
        self.mondayToken = mondayToken; self.mondayBoardId = mondayBoardId; self.mondayBoardName = mondayBoardName; self.mondayGroupId = mondayGroupId; self.mondayGroupName = mondayGroupName; self.mondaySyncStatus = mondaySyncStatus; self.mondaySyncComments = mondaySyncComments; self.mondayStatusColumnId = mondayStatusColumnId; self.mondayVotesColumnId = mondayVotesColumnId; self.mondayIsActive = mondayIsActive
    }
}

public struct CreateMondayItemRequest: Content, Sendable { public var feedbackId: UUID; public init(feedbackId: UUID) { self.feedbackId = feedbackId } }
public struct CreateMondayItemResponse: Content, Sendable { public var feedbackId: UUID; public var itemUrl: String; public var itemId: String }
public struct BulkCreateMondayItemsRequest: Content, Sendable { public var feedbackIds: [UUID]; public init(feedbackIds: [UUID]) { self.feedbackIds = feedbackIds } }
public struct BulkCreateMondayItemsResponse: Content, Sendable { public var created: [CreateMondayItemResponse]; public var failed: [UUID] }
public struct MondayBoard: Content, Sendable { public var id: String; public var name: String }
public struct MondayGroup: Content, Sendable { public var id: String; public var title: String }
public struct MondayColumn: Content, Sendable { public var id: String; public var title: String; public var type: String }

// MARK: - Linear

public struct UpdateLinearSettingsRequest: Content, Sendable {
    public var linearToken: String?; public var linearTeamId: String?; public var linearTeamName: String?; public var linearProjectId: String?; public var linearProjectName: String?; public var linearDefaultLabelIds: [String]?; public var linearSyncStatus: Bool?; public var linearSyncComments: Bool?; public var linearIsActive: Bool?
    public init(linearToken: String? = nil, linearTeamId: String? = nil, linearTeamName: String? = nil, linearProjectId: String? = nil, linearProjectName: String? = nil, linearDefaultLabelIds: [String]? = nil, linearSyncStatus: Bool? = nil, linearSyncComments: Bool? = nil, linearIsActive: Bool? = nil) {
        self.linearToken = linearToken; self.linearTeamId = linearTeamId; self.linearTeamName = linearTeamName; self.linearProjectId = linearProjectId; self.linearProjectName = linearProjectName; self.linearDefaultLabelIds = linearDefaultLabelIds; self.linearSyncStatus = linearSyncStatus; self.linearSyncComments = linearSyncComments; self.linearIsActive = linearIsActive
    }
}

public struct CreateLinearIssueRequest: Content, Sendable { public var feedbackId: UUID; public var additionalLabelIds: [String]?; public init(feedbackId: UUID, additionalLabelIds: [String]? = nil) { self.feedbackId = feedbackId; self.additionalLabelIds = additionalLabelIds } }
public struct CreateLinearIssueResponse: Content, Sendable { public var feedbackId: UUID; public var issueUrl: String; public var issueId: String; public var identifier: String }
public struct BulkCreateLinearIssuesRequest: Content, Sendable { public var feedbackIds: [UUID]; public var additionalLabelIds: [String]?; public init(feedbackIds: [UUID], additionalLabelIds: [String]? = nil) { self.feedbackIds = feedbackIds; self.additionalLabelIds = additionalLabelIds } }
public struct BulkCreateLinearIssuesResponse: Content, Sendable { public var created: [CreateLinearIssueResponse]; public var failed: [UUID] }
public struct LinearTeam: Content, Sendable { public var id: String; public var name: String; public var key: String }
public struct LinearProject: Content, Sendable { public var id: String; public var name: String; public var state: String }
public struct LinearWorkflowState: Content, Sendable { public var id: String; public var name: String; public var type: String; public var position: Double }
public struct LinearLabel: Content, Sendable { public var id: String; public var name: String; public var color: String }

// MARK: - Trello

public struct UpdateTrelloSettingsRequest: Content, Sendable {
    public var trelloToken: String?; public var trelloBoardId: String?; public var trelloBoardName: String?; public var trelloListId: String?; public var trelloListName: String?; public var trelloSyncStatus: Bool?; public var trelloSyncComments: Bool?; public var trelloIsActive: Bool?
    public init(trelloToken: String? = nil, trelloBoardId: String? = nil, trelloBoardName: String? = nil, trelloListId: String? = nil, trelloListName: String? = nil, trelloSyncStatus: Bool? = nil, trelloSyncComments: Bool? = nil, trelloIsActive: Bool? = nil) {
        self.trelloToken = trelloToken; self.trelloBoardId = trelloBoardId; self.trelloBoardName = trelloBoardName; self.trelloListId = trelloListId; self.trelloListName = trelloListName; self.trelloSyncStatus = trelloSyncStatus; self.trelloSyncComments = trelloSyncComments; self.trelloIsActive = trelloIsActive
    }
}

public struct CreateTrelloCardRequest: Content, Sendable { public var feedbackId: UUID; public init(feedbackId: UUID) { self.feedbackId = feedbackId } }
public struct CreateTrelloCardResponse: Content, Sendable { public var feedbackId: UUID; public var cardUrl: String; public var cardId: String }
public struct BulkCreateTrelloCardsRequest: Content, Sendable { public var feedbackIds: [UUID]; public init(feedbackIds: [UUID]) { self.feedbackIds = feedbackIds } }
public struct BulkCreateTrelloCardsResponse: Content, Sendable { public var created: [CreateTrelloCardResponse]; public var failed: [UUID] }
public struct TrelloBoard: Content, Sendable { public var id: String; public var name: String }
public struct TrelloList: Content, Sendable { public var id: String; public var name: String }

// MARK: - Airtable

public struct UpdateAirtableSettingsRequest: Content, Sendable {
    public var airtableToken: String?; public var airtableBaseId: String?; public var airtableBaseName: String?; public var airtableTableId: String?; public var airtableTableName: String?; public var airtableSyncStatus: Bool?; public var airtableSyncComments: Bool?; public var airtableStatusFieldId: String?; public var airtableVotesFieldId: String?; public var airtableTitleFieldId: String?; public var airtableDescriptionFieldId: String?; public var airtableCategoryFieldId: String?; public var airtableIsActive: Bool?
    public init(airtableToken: String? = nil, airtableBaseId: String? = nil, airtableBaseName: String? = nil, airtableTableId: String? = nil, airtableTableName: String? = nil, airtableSyncStatus: Bool? = nil, airtableSyncComments: Bool? = nil, airtableStatusFieldId: String? = nil, airtableVotesFieldId: String? = nil, airtableTitleFieldId: String? = nil, airtableDescriptionFieldId: String? = nil, airtableCategoryFieldId: String? = nil, airtableIsActive: Bool? = nil) {
        self.airtableToken = airtableToken; self.airtableBaseId = airtableBaseId; self.airtableBaseName = airtableBaseName; self.airtableTableId = airtableTableId; self.airtableTableName = airtableTableName; self.airtableSyncStatus = airtableSyncStatus; self.airtableSyncComments = airtableSyncComments; self.airtableStatusFieldId = airtableStatusFieldId; self.airtableVotesFieldId = airtableVotesFieldId; self.airtableTitleFieldId = airtableTitleFieldId; self.airtableDescriptionFieldId = airtableDescriptionFieldId; self.airtableCategoryFieldId = airtableCategoryFieldId; self.airtableIsActive = airtableIsActive
    }
}

public struct CreateAirtableRecordRequest: Content, Sendable { public var feedbackId: UUID; public init(feedbackId: UUID) { self.feedbackId = feedbackId } }
public struct CreateAirtableRecordResponse: Content, Sendable { public var feedbackId: UUID; public var recordUrl: String; public var recordId: String }
public struct BulkCreateAirtableRecordsRequest: Content, Sendable { public var feedbackIds: [UUID]; public init(feedbackIds: [UUID]) { self.feedbackIds = feedbackIds } }
public struct BulkCreateAirtableRecordsResponse: Content, Sendable { public var created: [CreateAirtableRecordResponse]; public var failed: [UUID] }
public struct AirtableBase: Content, Sendable { public var id: String; public var name: String }
public struct AirtableTable: Content, Sendable { public var id: String; public var name: String }
public struct AirtableField: Content, Sendable { public var id: String; public var name: String; public var type: String }

// MARK: - Asana

public struct UpdateAsanaSettingsRequest: Content, Sendable {
    public var asanaToken: String?; public var asanaWorkspaceId: String?; public var asanaWorkspaceName: String?; public var asanaProjectId: String?; public var asanaProjectName: String?; public var asanaSectionId: String?; public var asanaSectionName: String?; public var asanaSyncStatus: Bool?; public var asanaSyncComments: Bool?; public var asanaStatusFieldId: String?; public var asanaVotesFieldId: String?; public var asanaIsActive: Bool?
    public init(asanaToken: String? = nil, asanaWorkspaceId: String? = nil, asanaWorkspaceName: String? = nil, asanaProjectId: String? = nil, asanaProjectName: String? = nil, asanaSectionId: String? = nil, asanaSectionName: String? = nil, asanaSyncStatus: Bool? = nil, asanaSyncComments: Bool? = nil, asanaStatusFieldId: String? = nil, asanaVotesFieldId: String? = nil, asanaIsActive: Bool? = nil) {
        self.asanaToken = asanaToken; self.asanaWorkspaceId = asanaWorkspaceId; self.asanaWorkspaceName = asanaWorkspaceName; self.asanaProjectId = asanaProjectId; self.asanaProjectName = asanaProjectName; self.asanaSectionId = asanaSectionId; self.asanaSectionName = asanaSectionName; self.asanaSyncStatus = asanaSyncStatus; self.asanaSyncComments = asanaSyncComments; self.asanaStatusFieldId = asanaStatusFieldId; self.asanaVotesFieldId = asanaVotesFieldId; self.asanaIsActive = asanaIsActive
    }
}

public struct CreateAsanaTaskRequest: Content, Sendable { public var feedbackId: UUID; public init(feedbackId: UUID) { self.feedbackId = feedbackId } }
public struct CreateAsanaTaskResponse: Content, Sendable { public var feedbackId: UUID; public var taskUrl: String; public var taskId: String }
public struct BulkCreateAsanaTasksRequest: Content, Sendable { public var feedbackIds: [UUID]; public init(feedbackIds: [UUID]) { self.feedbackIds = feedbackIds } }
public struct BulkCreateAsanaTasksResponse: Content, Sendable { public var created: [CreateAsanaTaskResponse]; public var failed: [UUID] }
public struct AsanaWorkspace: Content, Sendable { public var gid: String; public var name: String }
public struct AsanaProject: Content, Sendable { public var gid: String; public var name: String }
public struct AsanaSection: Content, Sendable { public var gid: String; public var name: String }
public struct AsanaCustomField: Content, Sendable { public var gid: String; public var name: String; public var type: String; public var enumOptions: [AsanaEnumOption]? }
public struct AsanaEnumOption: Content, Sendable { public var gid: String; public var name: String; public var enabled: Bool; public var color: String? }

// MARK: - Basecamp

public struct UpdateBasecampSettingsRequest: Content, Sendable {
    public var basecampAccessToken: String?; public var basecampAccountId: String?; public var basecampAccountName: String?; public var basecampProjectId: String?; public var basecampProjectName: String?; public var basecampTodosetId: String?; public var basecampTodolistId: String?; public var basecampTodolistName: String?; public var basecampSyncStatus: Bool?; public var basecampSyncComments: Bool?; public var basecampIsActive: Bool?
    public init(basecampAccessToken: String? = nil, basecampAccountId: String? = nil, basecampAccountName: String? = nil, basecampProjectId: String? = nil, basecampProjectName: String? = nil, basecampTodosetId: String? = nil, basecampTodolistId: String? = nil, basecampTodolistName: String? = nil, basecampSyncStatus: Bool? = nil, basecampSyncComments: Bool? = nil, basecampIsActive: Bool? = nil) {
        self.basecampAccessToken = basecampAccessToken; self.basecampAccountId = basecampAccountId; self.basecampAccountName = basecampAccountName; self.basecampProjectId = basecampProjectId; self.basecampProjectName = basecampProjectName; self.basecampTodosetId = basecampTodosetId; self.basecampTodolistId = basecampTodolistId; self.basecampTodolistName = basecampTodolistName; self.basecampSyncStatus = basecampSyncStatus; self.basecampSyncComments = basecampSyncComments; self.basecampIsActive = basecampIsActive
    }
}

public struct CreateBasecampTodoRequest: Content, Sendable { public var feedbackId: UUID; public init(feedbackId: UUID) { self.feedbackId = feedbackId } }
public struct CreateBasecampTodoResponse: Content, Sendable { public var feedbackId: UUID; public var todoUrl: String; public var todoId: String }
public struct BulkCreateBasecampTodosRequest: Content, Sendable { public var feedbackIds: [UUID]; public init(feedbackIds: [UUID]) { self.feedbackIds = feedbackIds } }
public struct BulkCreateBasecampTodosResponse: Content, Sendable { public var created: [CreateBasecampTodoResponse]; public var failed: [UUID] }
public struct BasecampAccount: Content, Sendable { public var id: Int; public var name: String }
public struct BasecampProject: Content, Sendable { public var id: Int; public var name: String; public var todosetId: String? }
public struct BasecampTodolist: Content, Sendable { public var id: Int; public var name: String }

// MARK: - Email Campaign

public struct UpdateEmailCampaignSettingsRequest: Content, Sendable {
    public var emailCampaignService: String?; public var emailCampaignApiKey: String?; public var emailCampaignServerPrefix: String?; public var emailCampaignListId: String?; public var emailCampaignListName: String?; public var emailCampaignDefaultTags: [String]?; public var emailCampaignIsActive: Bool?
    public init(emailCampaignService: String? = nil, emailCampaignApiKey: String? = nil, emailCampaignServerPrefix: String? = nil, emailCampaignListId: String? = nil, emailCampaignListName: String? = nil, emailCampaignDefaultTags: [String]? = nil, emailCampaignIsActive: Bool? = nil) {
        self.emailCampaignService = emailCampaignService; self.emailCampaignApiKey = emailCampaignApiKey; self.emailCampaignServerPrefix = emailCampaignServerPrefix; self.emailCampaignListId = emailCampaignListId; self.emailCampaignListName = emailCampaignListName; self.emailCampaignDefaultTags = emailCampaignDefaultTags; self.emailCampaignIsActive = emailCampaignIsActive
    }
}

public struct EmailCampaignList: Content, Sendable { public var id: String; public var name: String }
