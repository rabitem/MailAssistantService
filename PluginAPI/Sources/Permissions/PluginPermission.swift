import Foundation

// MARK: - Plugin Permission

/// Permissions that plugins can request from the system
public enum PluginPermission: String, Codable, Sendable, CaseIterable {
    
    // MARK: - Email Access Permissions
    
    /// Read email content
    case readEmails = "read_emails"
    
    /// Read email metadata (headers, dates, etc.) without content
    case readEmailMetadata = "read_email_metadata"
    
    /// Send emails on behalf of the user
    case sendEmails = "send_emails"
    
    /// Draft emails (save as drafts without sending)
    case draftEmails = "draft_emails"
    
    /// Modify email status (mark as read, flag, archive, etc.)
    case modifyEmailStatus = "modify_email_status"
    
    /// Delete emails
    case deleteEmails = "delete_emails"
    
    /// Move emails between folders
    case moveEmails = "move_emails"
    
    /// Access email attachments
    case accessAttachments = "access_attachments"
    
    /// Download attachments
    case downloadAttachments = "download_attachments"
    
    // MARK: - Thread Permissions
    
    /// Read email threads
    case readThreads = "read_threads"
    
    /// Modify thread status
    case modifyThreads = "modify_threads"
    
    // MARK: - Folder/Label Permissions
    
    /// Read folder structure
    case readFolders = "read_folders"
    
    /// Create/modify folders
    case manageFolders = "manage_folders"
    
    /// Apply/remove labels
    case manageLabels = "manage_labels"
    
    // MARK: - Contact Permissions
    
    /// Read contacts
    case readContacts = "read_contacts"
    
    /// Modify contacts
    case modifyContacts = "modify_contacts"
    
    /// Access contact groups
    case manageContactGroups = "manage_contact_groups"
    
    // MARK: - AI/Analysis Permissions
    
    /// Use AI generation capabilities
    case useAI = "use_ai"
    
    /// Request AI analysis of emails
    case analyzeEmails = "analyze_emails"
    
    /// Access writing style profiles
    case accessWritingProfiles = "access_writing_profiles"
    
    /// Modify writing style profiles
    case modifyWritingProfiles = "modify_writing_profiles"
    
    // MARK: - Integration Permissions
    
    /// Connect to external services
    case connectIntegrations = "connect_integrations"
    
    /// Sync data with external services
    case syncData = "sync_data"
    
    /// Access calendar
    case accessCalendar = "access_calendar"
    
    /// Access task manager
    case accessTasks = "access_tasks"
    
    /// Access cloud storage
    case accessCloudStorage = "access_cloud_storage"
    
    /// Access CRM
    case accessCRM = "access_crm"
    
    // MARK: - UI Permissions
    
    /// Add custom UI panels
    case addPanels = "add_panels"
    
    /// Add toolbar items
    case addToolbarItems = "add_toolbar_items"
    
    /// Add context menu items
    case addContextMenuItems = "add_context_menu_items"
    
    /// Show notifications
    case showNotifications = "show_notifications"
    
    /// Modify application theme/appearance
    case modifyAppearance = "modify_appearance"
    
    // MARK: - Automation Permissions
    
    /// Create automation rules
    case createRules = "create_rules"
    
    /// Run workflows
    case runWorkflows = "run_workflows"
    
    /// Schedule actions
    case scheduleActions = "schedule_actions"
    
    // MARK: - System Permissions
    
    /// Access network (make HTTP requests)
    case networkAccess = "network_access"
    
    /// Access local file system
    case fileSystemAccess = "file_system_access"
    
    /// Access keychain for secure storage
    case keychainAccess = "keychain_access"
    
    /// Run in background
    case backgroundExecution = "background_execution"
    
    /// Access system clipboard
    case clipboardAccess = "clipboard_access"
    
    /// Open external URLs
    case openURLs = "open_urls"
    
    /// Execute shell commands
    case shellExecution = "shell_execution"
    
    // MARK: - Data Permissions
    
    /// Read app settings
    case readSettings = "read_settings"
    
    /// Modify app settings
    case modifySettings = "modify_settings"
    
    /// Export user data
    case exportData = "export_data"
    
    /// Import data
    case importData = "import_data"
    
    /// Access usage analytics
    case accessAnalytics = "access_analytics"
    
    // MARK: - Plugin Permissions
    
    /// Communicate with other plugins
    case interPluginCommunication = "inter_plugin_communication"
    
    /// Install other plugins
    case installPlugins = "install_plugins"
    
    /// Access plugin storage
    case pluginStorage = "plugin_storage"
    
    // MARK: - Permission Groups
    
    /// All email-related permissions
    public static var emailPermissions: [PluginPermission] {
        [
            .readEmails, .readEmailMetadata, .sendEmails, .draftEmails,
            .modifyEmailStatus, .deleteEmails, .moveEmails,
            .accessAttachments, .downloadAttachments,
            .readThreads, .modifyThreads
        ]
    }
    
    /// All AI/analysis permissions
    public static var aiPermissions: [PluginPermission] {
        [.useAI, .analyzeEmails, .accessWritingProfiles, .modifyWritingProfiles]
    }
    
    /// All integration permissions
    public static var integrationPermissions: [PluginPermission] {
        [
            .connectIntegrations, .syncData,
            .accessCalendar, .accessTasks, .accessCloudStorage, .accessCRM
        ]
    }
    
    /// All UI permissions
    public static var uiPermissions: [PluginPermission] {
        [
            .addPanels, .addToolbarItems, .addContextMenuItems,
            .showNotifications, .modifyAppearance
        ]
    }
    
    /// All system permissions (most sensitive)
    public static var systemPermissions: [PluginPermission] {
        [
            .networkAccess, .fileSystemAccess, .keychainAccess,
            .backgroundExecution, .clipboardAccess, .openURLs, .shellExecution
        ]
    }
    
    /// All automation permissions
    public static var automationPermissions: [PluginPermission] {
        [.createRules, .runWorkflows, .scheduleActions]
    }
    
    /// Minimal permissions (read-only)
    public static var minimalPermissions: [PluginPermission] {
        [.readEmailMetadata, .readFolders, .readSettings]
    }
    
    /// Standard permissions for analysis plugins
    public static var analysisPluginPermissions: [PluginPermission] {
        [
            .readEmails, .readEmailMetadata, .readThreads,
            .analyzeEmails, .useAI,
            .showNotifications, .pluginStorage
        ]
    }
    
    /// Standard permissions for AI provider plugins
    public static var aiProviderPermissions: [PluginPermission] {
        [.useAI, .networkAccess, .pluginStorage, .accessWritingProfiles]
    }
    
    /// Standard permissions for action plugins
    public static var actionPluginPermissions: [PluginPermission] {
        [
            .readEmails, .readEmailMetadata, .modifyEmailStatus,
            .sendEmails, .draftEmails, .moveEmails,
            .showNotifications, .pluginStorage
        ]
    }
    
    /// Standard permissions for integration plugins
    public static var integrationPluginPermissions: [PluginPermission] {
        [
            .connectIntegrations, .syncData, .networkAccess,
            .keychainAccess, .pluginStorage,
            .readEmails, .readEmailMetadata
        ]
    }
    
    /// Standard permissions for UI plugins
    public static var uiPluginPermissions: [PluginPermission] {
        [
            .addPanels, .addToolbarItems, .addContextMenuItems,
            .showNotifications, .readEmails, .readSettings,
            .pluginStorage
        ]
    }
}

// MARK: - Permission Description

public struct PermissionDescription: Sendable {
    public let permission: PluginPermission
    public let title: String
    public let description: String
    public let riskLevel: PermissionRiskLevel
    public let category: PermissionCategory
    
    public init(
        permission: PluginPermission,
        title: String,
        description: String,
        riskLevel: PermissionRiskLevel,
        category: PermissionCategory
    ) {
        self.permission = permission
        self.title = title
        self.description = description
        self.riskLevel = riskLevel
        self.category = category
    }
}

// MARK: - Permission Risk Level

public enum PermissionRiskLevel: String, Codable, Sendable, Comparable {
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var numericValue: Int {
        switch self {
        case .minimal: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
    
    public static func < (lhs: PermissionRiskLevel, rhs: PermissionRiskLevel) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

// MARK: - Permission Category

public enum PermissionCategory: String, Codable, Sendable {
    case email = "email"
    case contacts = "contacts"
    case ai = "ai"
    case integration = "integration"
    case ui = "ui"
    case automation = "automation"
    case system = "system"
    case data = "data"
    case plugin = "plugin"
}

// MARK: - Permission Registry

/// Registry of all permission descriptions
public struct PermissionRegistry {
    public static let descriptions: [PluginPermission: PermissionDescription] = [
        // Email permissions
        .readEmails: PermissionDescription(
            permission: .readEmails,
            title: "Read Emails",
            description: "Access the content of your emails",
            riskLevel: .high,
            category: .email
        ),
        .readEmailMetadata: PermissionDescription(
            permission: .readEmailMetadata,
            title: "Read Email Metadata",
            description: "Access email headers, dates, and sender information without content",
            riskLevel: .low,
            category: .email
        ),
        .sendEmails: PermissionDescription(
            permission: .sendEmails,
            title: "Send Emails",
            description: "Send emails on your behalf",
            riskLevel: .critical,
            category: .email
        ),
        .draftEmails: PermissionDescription(
            permission: .draftEmails,
            title: "Draft Emails",
            description: "Create email drafts",
            riskLevel: .medium,
            category: .email
        ),
        .modifyEmailStatus: PermissionDescription(
            permission: .modifyEmailStatus,
            title: "Modify Email Status",
            description: "Mark emails as read, flag them, or archive them",
            riskLevel: .medium,
            category: .email
        ),
        .deleteEmails: PermissionDescription(
            permission: .deleteEmails,
            title: "Delete Emails",
            description: "Permanently delete emails",
            riskLevel: .high,
            category: .email
        ),
        .moveEmails: PermissionDescription(
            permission: .moveEmails,
            title: "Move Emails",
            description: "Move emails between folders",
            riskLevel: .medium,
            category: .email
        ),
        .accessAttachments: PermissionDescription(
            permission: .accessAttachments,
            title: "Access Attachments",
            description: "View email attachments",
            riskLevel: .medium,
            category: .email
        ),
        .downloadAttachments: PermissionDescription(
            permission: .downloadAttachments,
            title: "Download Attachments",
            description: "Download email attachments to your device",
            riskLevel: .medium,
            category: .email
        ),
        
        // AI permissions
        .useAI: PermissionDescription(
            permission: .useAI,
            title: "Use AI",
            description: "Use AI for text generation and processing",
            riskLevel: .medium,
            category: .ai
        ),
        .analyzeEmails: PermissionDescription(
            permission: .analyzeEmails,
            title: "Analyze Emails",
            description: "Use AI to analyze email content for insights",
            riskLevel: .high,
            category: .ai
        ),
        
        // Integration permissions
        .connectIntegrations: PermissionDescription(
            permission: .connectIntegrations,
            title: "Connect Integrations",
            description: "Connect to external services like calendars and task managers",
            riskLevel: .medium,
            category: .integration
        ),
        .syncData: PermissionDescription(
            permission: .syncData,
            title: "Sync Data",
            description: "Sync data with external services",
            riskLevel: .medium,
            category: .integration
        ),
        
        // System permissions
        .networkAccess: PermissionDescription(
            permission: .networkAccess,
            title: "Network Access",
            description: "Make network requests to external servers",
            riskLevel: .medium,
            category: .system
        ),
        .fileSystemAccess: PermissionDescription(
            permission: .fileSystemAccess,
            title: "File System Access",
            description: "Access files on your device",
            riskLevel: .high,
            category: .system
        ),
        .keychainAccess: PermissionDescription(
            permission: .keychainAccess,
            title: "Keychain Access",
            description: "Store and retrieve passwords securely",
            riskLevel: .high,
            category: .system
        ),
        
        // UI permissions
        .addPanels: PermissionDescription(
            permission: .addPanels,
            title: "Add Panels",
            description: "Add custom panels to the interface",
            riskLevel: .low,
            category: .ui
        ),
        .showNotifications: PermissionDescription(
            permission: .showNotifications,
            title: "Show Notifications",
            description: "Display notification messages",
            riskLevel: .low,
            category: .ui
        )
    ]
    
    public static func description(for permission: PluginPermission) -> PermissionDescription {
        descriptions[permission] ?? PermissionDescription(
            permission: permission,
            title: permission.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
            description: "",
            riskLevel: .medium,
            category: .plugin
        )
    }
}

// MARK: - Permission Request

/// A request for permissions from a plugin
public struct PermissionRequest: Sendable {
    public let pluginID: String
    public let pluginName: String
    public let permissions: [PluginPermission]
    public let reason: String
    
    public init(
        pluginID: String,
        pluginName: String,
        permissions: [PluginPermission],
        reason: String
    ) {
        self.pluginID = pluginID
        self.pluginName = pluginName
        self.permissions = permissions
        self.reason = reason
    }
    
    public var highestRiskLevel: PermissionRiskLevel {
        permissions
            .map { PermissionRegistry.description(for: $0).riskLevel }
            .max() ?? .minimal
    }
}

// MARK: - Permission Response

public struct PermissionResponse: Sendable {
    public let granted: [PluginPermission]
    public let denied: [PluginPermission]
    public let timestamp: Date
    
    public init(
        granted: [PluginPermission] = [],
        denied: [PluginPermission] = [],
        timestamp: Date = Date()
    ) {
        self.granted = granted
        self.denied = denied
        self.timestamp = timestamp
    }
    
    public var allGranted: Bool {
        denied.isEmpty
    }
}

// MARK: - Permission State

/// Tracks the state of permissions for a plugin
public struct PermissionState: Codable, Sendable {
    public let pluginID: String
    public let granted: [PluginPermission]
    public let denied: [PluginPermission]
    public let pending: [PluginPermission]
    public let lastUpdated: Date
    
    public init(
        pluginID: String,
        granted: [PluginPermission] = [],
        denied: [PluginPermission] = [],
        pending: [PluginPermission] = [],
        lastUpdated: Date = Date()
    ) {
        self.pluginID = pluginID
        self.granted = granted
        self.denied = denied
        self.pending = pending
        self.lastUpdated = lastUpdated
    }
    
    public func hasPermission(_ permission: PluginPermission) -> Bool {
        granted.contains(permission)
    }
    
    public func canAccess(_ permissions: [PluginPermission]) -> Bool {
        permissions.allSatisfy { granted.contains($0) }
    }
}
