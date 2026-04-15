import Vapor

// MARK: - Enums

public enum ProjectRole: String, Content, Sendable {
    case admin
    case member
    case viewer
}

// MARK: - Requests

public struct CreateProjectRequest: Content, Sendable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct UpdateProjectRequest: Content, Sendable {
    public let name: String?
    public let description: String?
    public let colorIndex: Int?

    public init(name: String? = nil, description: String? = nil, colorIndex: Int? = nil) {
        self.name = name
        self.description = description
        self.colorIndex = colorIndex
    }
}

public struct TransferOwnershipRequest: Content, Sendable {
    public let newOwnerId: UUID?
    public let newOwnerEmail: String?

    public init(newOwnerId: UUID? = nil, newOwnerEmail: String? = nil) {
        self.newOwnerId = newOwnerId
        self.newOwnerEmail = newOwnerEmail
    }
}

// MARK: - Responses

public struct ProjectResponse: Content, Sendable {
    public let id: UUID
    public let name: String
    public let apiKey: String
    public let description: String?
    public let ownerId: UUID
    public let ownerEmail: String?
    public let isArchived: Bool
    public let archivedAt: Date?
    public let colorIndex: Int
    public let logoUrl: String?
    public let feedbackCount: Int
    public let memberCount: Int
    public let createdAt: Date?
    public let updatedAt: Date?
    // Slack
    public let slackWebhookURL: String?
    public let slackNotifyNewFeedback: Bool
    public let slackNotifyNewComments: Bool
    public let slackNotifyStatusChanges: Bool
    public let slackIsActive: Bool
    public let allowedStatuses: [String]
    public let emailNotifyStatuses: [String]
    // GitHub
    public let githubOwner: String?
    public let githubRepo: String?
    public let githubToken: String?
    public let githubDefaultLabels: [String]?
    public let githubSyncStatus: Bool
    public let githubIsActive: Bool
    // ClickUp
    public let clickupToken: String?
    public let clickupListId: String?
    public let clickupWorkspaceName: String?
    public let clickupListName: String?
    public let clickupDefaultTags: [String]?
    public let clickupSyncStatus: Bool
    public let clickupSyncComments: Bool
    public let clickupVotesFieldId: String?
    public let clickupIsActive: Bool
    // Notion
    public let notionToken: String?
    public let notionDatabaseId: String?
    public let notionDatabaseName: String?
    public let notionSyncStatus: Bool
    public let notionSyncComments: Bool
    public let notionStatusProperty: String?
    public let notionVotesProperty: String?
    public let notionIsActive: Bool
    // Monday
    public let mondayToken: String?
    public let mondayBoardId: String?
    public let mondayBoardName: String?
    public let mondayGroupId: String?
    public let mondayGroupName: String?
    public let mondaySyncStatus: Bool
    public let mondaySyncComments: Bool
    public let mondayStatusColumnId: String?
    public let mondayVotesColumnId: String?
    public let mondayIsActive: Bool
    // Linear
    public let linearToken: String?
    public let linearTeamId: String?
    public let linearTeamName: String?
    public let linearProjectId: String?
    public let linearProjectName: String?
    public let linearDefaultLabelIds: [String]?
    public let linearSyncStatus: Bool
    public let linearSyncComments: Bool
    public let linearIsActive: Bool
    // Trello
    public let trelloToken: String?
    public let trelloBoardId: String?
    public let trelloBoardName: String?
    public let trelloListId: String?
    public let trelloListName: String?
    public let trelloSyncStatus: Bool
    public let trelloSyncComments: Bool
    public let trelloIsActive: Bool
    // Airtable
    public let airtableToken: String?
    public let airtableBaseId: String?
    public let airtableBaseName: String?
    public let airtableTableId: String?
    public let airtableTableName: String?
    public let airtableSyncStatus: Bool
    public let airtableSyncComments: Bool
    public let airtableStatusFieldId: String?
    public let airtableVotesFieldId: String?
    public let airtableTitleFieldId: String?
    public let airtableDescriptionFieldId: String?
    public let airtableCategoryFieldId: String?
    public let airtableIsActive: Bool
    // Asana
    public let asanaToken: String?
    public let asanaWorkspaceId: String?
    public let asanaWorkspaceName: String?
    public let asanaProjectId: String?
    public let asanaProjectName: String?
    public let asanaSectionId: String?
    public let asanaSectionName: String?
    public let asanaSyncStatus: Bool
    public let asanaSyncComments: Bool
    public let asanaStatusFieldId: String?
    public let asanaVotesFieldId: String?
    public let asanaIsActive: Bool
    // Basecamp
    public let basecampAccessToken: String?
    public let basecampAccountId: String?
    public let basecampAccountName: String?
    public let basecampProjectId: String?
    public let basecampProjectName: String?
    public let basecampTodosetId: String?
    public let basecampTodolistId: String?
    public let basecampTodolistName: String?
    public let basecampSyncStatus: Bool
    public let basecampSyncComments: Bool
    public let basecampIsActive: Bool
    // Email Campaign
    public let emailCampaignService: String?
    public let emailCampaignApiKey: String?
    public let emailCampaignServerPrefix: String?
    public let emailCampaignListId: String?
    public let emailCampaignListName: String?
    public let emailCampaignDefaultTags: [String]?
    public let emailCampaignIsActive: Bool
    // Embed
    public let isEmbedEnabled: Bool
    public let embedVisibleStatuses: [String]?
    public let embedAllowVoting: Bool
    public let embedTheme: String?
    public let embedUrl: String?
}

public struct ProjectListItem: Content, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let isArchived: Bool
    public let isOwner: Bool
    public let role: ProjectRole?
    public let colorIndex: Int
    public let logoUrl: String?
    public let feedbackCount: Int
    public let createdAt: Date?
}

public struct TransferOwnershipResponse: Content, Sendable {
    public let projectId: UUID
    public let projectName: String
    public let newOwner: UserSummary
    public let previousOwner: UserSummary
    public let transferredAt: Date

    public struct UserSummary: Content, Sendable {
        public let id: UUID
        public let email: String
        public let name: String
    }
}

// MARK: - Members

public struct ProjectMemberPublic: Content, Sendable {
    public let id: UUID
    public let userId: UUID
    public let userEmail: String
    public let userName: String
    public let role: ProjectRole
    public let createdAt: Date?
}

public struct AddMemberRequest: Content, Sendable {
    public let email: String
    public let role: ProjectRole

    public init(email: String, role: ProjectRole) {
        self.email = email
        self.role = role
    }
}

public struct UpdateMemberRoleRequest: Content, Sendable {
    public let role: ProjectRole

    public init(role: ProjectRole) {
        self.role = role
    }
}

public struct AddMemberResponse: Content, Sendable {
    public let member: ProjectMemberPublic?
    public let invite: ProjectInviteResponse?
    public let inviteSent: Bool
}

// MARK: - Invites

public struct ProjectInviteResponse: Content, Sendable {
    public let id: UUID
    public let email: String
    public let role: ProjectRole
    public let code: String
    public let expiresAt: Date
    public let createdAt: Date?
}

public struct AcceptInviteRequest: Content, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

public struct AcceptInviteResponse: Content, Sendable {
    public let projectId: UUID
    public let projectName: String
    public let role: ProjectRole
}

public struct InvitePreviewResponse: Content, Sendable {
    public let projectName: String
    public let projectDescription: String?
    public let invitedByName: String
    public let role: ProjectRole
    public let expiresAt: Date
    public let emailMatches: Bool
    public let inviteEmail: String
}

// MARK: - Settings

public struct UpdateSlackSettingsRequest: Content, Sendable {
    public var slackWebhookUrl: String?
    public var slackNotifyNewFeedback: Bool?
    public var slackNotifyNewComments: Bool?
    public var slackNotifyStatusChanges: Bool?
    public var slackIsActive: Bool?

    public init(
        slackWebhookUrl: String? = nil,
        slackNotifyNewFeedback: Bool? = nil,
        slackNotifyNewComments: Bool? = nil,
        slackNotifyStatusChanges: Bool? = nil,
        slackIsActive: Bool? = nil
    ) {
        self.slackWebhookUrl = slackWebhookUrl
        self.slackNotifyNewFeedback = slackNotifyNewFeedback
        self.slackNotifyNewComments = slackNotifyNewComments
        self.slackNotifyStatusChanges = slackNotifyStatusChanges
        self.slackIsActive = slackIsActive
    }
}

public struct UpdateAllowedStatusesRequest: Content, Sendable {
    public let allowedStatuses: [String]

    public init(allowedStatuses: [String]) {
        self.allowedStatuses = allowedStatuses
    }
}

public struct UpdateEmailNotifyStatusesRequest: Content, Sendable {
    public let emailNotifyStatuses: [String]

    public init(emailNotifyStatuses: [String]) {
        self.emailNotifyStatuses = emailNotifyStatuses
    }
}
