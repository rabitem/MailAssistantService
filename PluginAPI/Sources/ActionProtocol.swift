import Foundation

// MARK: - Action Plugin

/// Protocol for plugins that perform actions on emails or the system
public protocol ActionPlugin: Plugin {
    /// The actions this plugin can perform
    var supportedActions: [ActionType] { get }
    
    /// Execute an action
    func execute(action: ActionType, context: ActionContext) async throws -> ActionResult
    
    /// Check if this plugin can execute a specific action in the given context
    func canExecute(action: ActionType, context: ActionContext) async -> Bool
    
    /// Validate action parameters before execution
    func validateParameters(action: ActionType, parameters: [String: AnyCodable]) -> ValidationResult
    
    /// Get the UI representation for an action (icon, label, etc.)
    func actionMetadata(for action: ActionType) -> ActionMetadata
}

// MARK: - Action Type

/// Types of actions that can be performed
public enum ActionType: String, Codable, Sendable, CaseIterable {
    // Email actions
    case sendEmail = "send_email"
    case draftReply = "draft_reply"
    case forwardEmail = "forward_email"
    case archiveEmail = "archive_email"
    case deleteEmail = "delete_email"
    case markAsRead = "mark_as_read"
    case markAsUnread = "mark_as_unread"
    case moveToFolder = "move_to_folder"
    case addLabel = "add_label"
    case removeLabel = "remove_label"
    case flagEmail = "flag_email"
    case snoozeEmail = "snooze_email"
    
    // Automation actions
    case createRule = "create_rule"
    case runWorkflow = "run_workflow"
    case scheduleSend = "schedule_send"
    
    // External actions
    case createCalendarEvent = "create_calendar_event"
    case createTask = "create_task"
    case createReminder = "create_reminder"
    case openURL = "open_url"
    case openApp = "open_app"
    
    // Communication actions
    case sendNotification = "send_notification"
    case shareContent = "share_content"
    
    // Custom action
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = ActionType(rawValue: rawValue) {
            self = standard
        } else {
            self = .custom(rawValue)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .custom(let value):
            try container.encode(value)
        default:
            try container.encode(self.rawValue)
        }
    }
    
    public var rawValue: String {
        switch self {
        case .sendEmail: return "send_email"
        case .draftReply: return "draft_reply"
        case .forwardEmail: return "forward_email"
        case .archiveEmail: return "archive_email"
        case .deleteEmail: return "delete_email"
        case .markAsRead: return "mark_as_read"
        case .markAsUnread: return "mark_as_unread"
        case .moveToFolder: return "move_to_folder"
        case .addLabel: return "add_label"
        case .removeLabel: return "remove_label"
        case .flagEmail: return "flag_email"
        case .snoozeEmail: return "snooze_email"
        case .createRule: return "create_rule"
        case .runWorkflow: return "run_workflow"
        case .scheduleSend: return "schedule_send"
        case .createCalendarEvent: return "create_calendar_event"
        case .createTask: return "create_task"
        case .createReminder: return "create_reminder"
        case .openURL: return "open_url"
        case .openApp: return "open_app"
        case .sendNotification: return "send_notification"
        case .shareContent: return "share_content"
        case .custom(let value): return value
        }
    }
    
    public static var allCases: [ActionType] {
        [
            .sendEmail, .draftReply, .forwardEmail,
            .archiveEmail, .deleteEmail, .markAsRead, .markAsUnread,
            .moveToFolder, .addLabel, .removeLabel, .flagEmail, .snoozeEmail,
            .createRule, .runWorkflow, .scheduleSend,
            .createCalendarEvent, .createTask, .createReminder,
            .openURL, .openApp, .sendNotification, .shareContent
        ]
    }
}

// MARK: - Action Context

/// Context for executing an action
public struct ActionContext: Sendable {
    /// The email being acted upon (if applicable)
    public let email: Email?
    
    /// The thread containing the email (if applicable)
    public let thread: EmailThread?
    
    /// Parameters for the action
    public let parameters: [String: AnyCodable]
    
    /// The user who triggered the action
    public let userID: String
    
    /// Source of the action trigger
    public let trigger: ActionTrigger
    
    /// Whether to execute immediately or queue
    public let executeImmediately: Bool
    
    /// Timeout for the action
    public let timeout: TimeInterval
    
    public init(
        email: Email? = nil,
        thread: EmailThread? = nil,
        parameters: [String: AnyCodable] = [:],
        userID: String,
        trigger: ActionTrigger,
        executeImmediately: Bool = true,
        timeout: TimeInterval = 30
    ) {
        self.email = email
        self.thread = thread
        self.parameters = parameters
        self.userID = userID
        self.trigger = trigger
        self.executeImmediately = executeImmediately
        self.timeout = timeout
    }
}

// MARK: - Action Trigger

/// Describes what triggered an action
public enum ActionTrigger: Codable, Sendable {
    /// User manually triggered the action
    case userInteraction(source: String)
    
    /// An automation rule triggered the action
    case automation(ruleID: String)
    
    /// Another plugin triggered the action
    case plugin(pluginID: String)
    
    /// A keyboard shortcut triggered the action
    case keyboardShortcut(keyCombo: String)
    
    /// Scheduled/triggered by time
    case scheduled(scheduleID: String)
    
    /// Triggered via API/webhook
    case api(source: String)
    
    private enum CodingKeys: String, CodingKey {
        case type, source, ruleID, pluginID, keyCombo, scheduleID
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "userInteraction":
            let source = try container.decode(String.self, forKey: .source)
            self = .userInteraction(source: source)
        case "automation":
            let ruleID = try container.decode(String.self, forKey: .ruleID)
            self = .automation(ruleID: ruleID)
        case "plugin":
            let pluginID = try container.decode(String.self, forKey: .pluginID)
            self = .plugin(pluginID: pluginID)
        case "keyboardShortcut":
            let keyCombo = try container.decode(String.self, forKey: .keyCombo)
            self = .keyboardShortcut(keyCombo: keyCombo)
        case "scheduled":
            let scheduleID = try container.decode(String.self, forKey: .scheduleID)
            self = .scheduled(scheduleID: scheduleID)
        case "api":
            let source = try container.decode(String.self, forKey: .source)
            self = .api(source: source)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown trigger type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .userInteraction(let source):
            try container.encode("userInteraction", forKey: .type)
            try container.encode(source, forKey: .source)
        case .automation(let ruleID):
            try container.encode("automation", forKey: .type)
            try container.encode(ruleID, forKey: .ruleID)
        case .plugin(let pluginID):
            try container.encode("plugin", forKey: .type)
            try container.encode(pluginID, forKey: .pluginID)
        case .keyboardShortcut(let keyCombo):
            try container.encode("keyboardShortcut", forKey: .type)
            try container.encode(keyCombo, forKey: .keyCombo)
        case .scheduled(let scheduleID):
            try container.encode("scheduled", forKey: .type)
            try container.encode(scheduleID, forKey: .scheduleID)
        case .api(let source):
            try container.encode("api", forKey: .type)
            try container.encode(source, forKey: .source)
        }
    }
}

// MARK: - Action Result

/// Result of executing an action
public struct ActionResult: Sendable {
    public let success: Bool
    public let action: ActionType
    public let message: String
    public let data: [String: AnyCodable]
    public let executionTime: TimeInterval
    public let timestamp: Date
    public let sideEffects: [SideEffect]
    
    public init(
        success: Bool,
        action: ActionType,
        message: String,
        data: [String: AnyCodable] = [:],
        executionTime: TimeInterval,
        timestamp: Date = Date(),
        sideEffects: [SideEffect] = []
    ) {
        self.success = success
        self.action = action
        self.message = message
        self.data = data
        self.executionTime = executionTime
        self.timestamp = timestamp
        self.sideEffects = sideEffects
    }
    
    public static func success(
        action: ActionType,
        message: String = "Action completed successfully",
        data: [String: AnyCodable] = [:],
        executionTime: TimeInterval = 0
    ) -> ActionResult {
        ActionResult(
            success: true,
            action: action,
            message: message,
            data: data,
            executionTime: executionTime
        )
    }
    
    public static func failure(
        action: ActionType,
        message: String,
        data: [String: AnyCodable] = [:],
        executionTime: TimeInterval = 0
    ) -> ActionResult {
        ActionResult(
            success: false,
            action: action,
            message: message,
            data: data,
            executionTime: executionTime
        )
    }
}

// MARK: - Side Effect

public struct SideEffect: Codable, Sendable {
    public let type: String
    public let description: String
    public let affectedResource: String?
    
    public init(type: String, description: String, affectedResource: String? = nil) {
        self.type = type
        self.description = description
        self.affectedResource = affectedResource
    }
}

// MARK: - Validation Result

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [ValidationError]
    public let warnings: [String]
    
    public init(isValid: Bool, errors: [ValidationError] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    public static let valid = ValidationResult(isValid: true)
}

// MARK: - Validation Error

public struct ValidationError: Codable, Sendable {
    public let field: String
    public let message: String
    public let code: String
    
    public init(field: String, message: String, code: String) {
        self.field = field
        self.message = message
        self.code = code
    }
}

// MARK: - Action Metadata

public struct ActionMetadata: Codable, Sendable {
    public let type: ActionType
    public let displayName: String
    public let description: String
    public let iconName: String
    public let shortcut: String?
    public let category: ActionCategory
    public let requiresEmail: Bool
    public let requiresConfirmation: Bool
    
    public init(
        type: ActionType,
        displayName: String,
        description: String,
        iconName: String,
        shortcut: String? = nil,
        category: ActionCategory = .general,
        requiresEmail: Bool = true,
        requiresConfirmation: Bool = false
    ) {
        self.type = type
        self.displayName = displayName
        self.description = description
        self.iconName = iconName
        self.shortcut = shortcut
        self.category = category
        self.requiresEmail = requiresEmail
        self.requiresConfirmation = requiresConfirmation
    }
}

// MARK: - Action Category

public enum ActionCategory: String, Codable, Sendable {
    case email = "email"
    case organization = "organization"
    case automation = "automation"
    case integration = "integration"
    case communication = "communication"
    case general = "general"
}

// MARK: - Email Thread

/// Represents a thread/conversation of emails
public struct EmailThread: Codable, Sendable, Identifiable {
    public let id: UUID
    public let subject: String
    public let participants: [EmailAddress]
    public let emails: [Email]
    public let lastActivity: Date
    
    public init(
        id: UUID = UUID(),
        subject: String,
        participants: [EmailAddress],
        emails: [Email],
        lastActivity: Date
    ) {
        self.id = id
        self.subject = subject
        self.participants = participants
        self.emails = emails
        self.lastActivity = lastActivity
    }
}
