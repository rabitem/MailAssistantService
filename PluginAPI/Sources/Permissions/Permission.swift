import Foundation

/// Permissions that plugins can request
public enum Permission: String, Codable, Sendable, CaseIterable {
    /// Read email content and metadata
    case readEmails = "read_emails"
    
    /// Modify email flags, labels, folders
    case modifyFolders = "modify_folders"
    
    /// Send emails
    case sendEmails = "send_emails"
    
    /// Access AI processing capabilities
    case aiProcessing = "ai_processing"
    
    /// Run background tasks
    case backgroundProcessing = "background_processing"
    
    /// Access network (external APIs)
    case networkAccess = "network_access"
    
    /// Access contacts
    case accessContacts = "access_contacts"
    
    /// Access calendar
    case accessCalendar = "access_calendar"
    
    /// Read/write to plugin's own storage
    case pluginStorage = "plugin_storage"
    
    /// Access system notifications
    case notifications = "notifications"
    
    /// Run custom scripts/commands
    case executeScripts = "execute_scripts"
    
    /// Access file system outside sandbox
    case fileSystemAccess = "file_system_access"
    
    /// Access keychain for credentials
    case keychainAccess = "keychain_access"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .readEmails:
            return "Read email content and metadata"
        case .modifyFolders:
            return "Modify folders, labels, and flags"
        case .sendEmails:
            return "Send emails on your behalf"
        case .aiProcessing:
            return "Use AI processing capabilities"
        case .backgroundProcessing:
            return "Run tasks in the background"
        case .networkAccess:
            return "Connect to external services"
        case .accessContacts:
            return "Access your contacts"
        case .accessCalendar:
            return "Access your calendar"
        case .pluginStorage:
            return "Store plugin data"
        case .notifications:
            return "Show notifications"
        case .executeScripts:
            return "Execute custom scripts"
        case .fileSystemAccess:
            return "Access files outside sandbox"
        case .keychainAccess:
            return "Access secure credentials"
        }
    }
    
    /// Whether this permission requires explicit user consent
    public var requiresUserConsent: Bool {
        switch self {
        case .readEmails, .sendEmails, .accessContacts, .accessCalendar, .networkAccess:
            return true
        case .modifyFolders, .aiProcessing, .backgroundProcessing, .pluginStorage, 
             .notifications, .executeScripts, .fileSystemAccess, .keychainAccess:
            return true
        }
    }
    
    /// Risk level of the permission
    public var riskLevel: PermissionRiskLevel {
        switch self {
        case .pluginStorage:
            return .low
        case .notifications, .backgroundProcessing:
            return .low
        case .aiProcessing, .modifyFolders:
            return .medium
        case .readEmails, .accessContacts, .accessCalendar:
            return .high
        case .sendEmails, .networkAccess, .fileSystemAccess, .executeScripts, .keychainAccess:
            return .critical
        }
    }
}

public enum PermissionRiskLevel: String, Sendable {
    case low
    case medium
    case high
    case critical
}
