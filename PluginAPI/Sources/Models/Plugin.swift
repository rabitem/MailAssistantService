import Foundation

/// Main plugin protocol that all plugins must conform to
public protocol Plugin: AnyObject, Sendable {
    /// Plugin manifest containing metadata
    var manifest: PluginManifest { get }
    
    /// Initialize the plugin with context
    /// - Parameter context: The plugin context providing access to system services
    init() async throws
    
    /// Called when plugin is loaded
    /// - Parameter context: Plugin context with initialized services
    func activate(context: PluginContext) async throws
    
    /// Called when plugin is being unloaded
    func deactivate() async
    
    /// Called when app settings change
    /// - Parameter settings: New settings dictionary
    func settingsChanged(_ settings: [String: Any]) async
    
    /// Get current plugin state
    var state: PluginState { get }
}

/// Default implementations
public extension Plugin {
    func settingsChanged(_ settings: [String: Any]) async {}
    var state: PluginState { .active }
}

/// Protocol for plugins that handle email processing
public protocol EmailProcessor: Plugin {
    /// Process an incoming email
    /// - Parameters:
    ///   - email: The email to process
    ///   - context: Processing context
    /// - Returns: Processing result with actions to take
    func processEmail(_ email: EmailMessage, context: ProcessingContext) async throws -> ProcessingResult
    
    /// Get processing priority (higher = earlier processing)
    var priority: Int { get }
}

public extension EmailProcessor {
    var priority: Int { 0 }
}

/// Protocol for plugins that provide AI capabilities
public protocol AIProvider: Plugin {
    /// Check if provider is available and configured
    var isAvailable: Bool { get async }
    
    /// Generate text completion
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - options: Generation options
    /// - Returns: Generated text
    func complete(prompt: String, options: AIOptions) async throws -> String
    
    /// Generate embeddings for text
    /// - Parameters:
    ///   - text: Input text
    ///   - options: Embedding options
    /// - Returns: Vector embedding
    func embed(text: String, options: AIOptions) async throws -> [Float]
}

/// Protocol for plugins that handle automation rules
public protocol AutomationRule: Plugin {
    /// Get all rules provided by this plugin
    var rules: [RuleDefinition] { get }
    
    /// Evaluate a rule against an email
    /// - Parameters:
    ///   - ruleId: The rule identifier
    ///   - email: The email to evaluate
    /// - Returns: Whether the rule matches
    func evaluate(ruleId: String, email: EmailMessage) async throws -> Bool
    
    /// Execute a rule's actions
    /// - Parameters:
    ///   - ruleId: The rule identifier
    ///   - email: The email to process
    /// - Returns: Actions to execute
    func execute(ruleId: String, email: EmailMessage) async throws -> [RuleAction]
}

/// Email message model
public struct EmailMessage: Sendable {
    public let id: String
    public let accountId: String
    public let subject: String
    public let sender: EmailAddress
    public let recipients: [EmailAddress]
    public let cc: [EmailAddress]
    public let bcc: [EmailAddress]
    public let body: EmailBody
    public let date: Date
    public let flags: EmailFlags
    public let labels: [String]
    public let attachments: [Attachment]
    public let threadId: String?
    
    public init(
        id: String,
        accountId: String,
        subject: String,
        sender: EmailAddress,
        recipients: [EmailAddress],
        cc: [EmailAddress] = [],
        bcc: [EmailAddress] = [],
        body: EmailBody,
        date: Date,
        flags: EmailFlags = EmailFlags(),
        labels: [String] = [],
        attachments: [Attachment] = [],
        threadId: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.subject = subject
        self.sender = sender
        self.recipients = recipients
        self.cc = cc
        self.bcc = bcc
        self.body = body
        self.date = date
        self.flags = flags
        self.labels = labels
        self.attachments = attachments
        self.threadId = threadId
    }
}

public struct EmailAddress: Sendable {
    public let address: String
    public let name: String?
    
    public init(address: String, name: String? = nil) {
        self.address = address
        self.name = name
    }
}

public struct EmailBody: Sendable {
    public let text: String?
    public let html: String?
    public let raw: Data?
    
    public init(text: String? = nil, html: String? = nil, raw: Data? = nil) {
        self.text = text
        self.html = html
        self.raw = raw
    }
}

public struct EmailFlags: Sendable {
    public let isRead: Bool
    public let isFlagged: Bool
    public let isReplied: Bool
    public let isDraft: Bool
    
    public init(
        isRead: Bool = false,
        isFlagged: Bool = false,
        isReplied: Bool = false,
        isDraft: Bool = false
    ) {
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.isReplied = isReplied
        self.isDraft = isDraft
    }
}

public struct Attachment: Sendable {
    public let id: String
    public let filename: String
    public let mimeType: String
    public let size: Int
    
    public init(id: String, filename: String, mimeType: String, size: Int) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
    }
}

public struct ProcessingContext: Sendable {
    public let accountId: String
    public let mailbox: String
    
    public init(accountId: String, mailbox: String) {
        self.accountId = accountId
        self.mailbox = mailbox
    }
}

public struct ProcessingResult: Sendable {
    public let actions: [EmailAction]
    public let confidence: Double
    public let metadata: [String: String]?
    
    public init(
        actions: [EmailAction] = [],
        confidence: Double = 1.0,
        metadata: [String: String]? = nil
    ) {
        self.actions = actions
        self.confidence = confidence
        self.metadata = metadata
    }
}

public enum EmailAction: Sendable {
    case move(toMailbox: String)
    case applyLabel(String)
    case removeLabel(String)
    case markAsRead
    case markAsUnread
    case flag
    case unflag
    case reply(template: String?)
    case forward(to: String)
    case delete
    case archive
    case notify(title: String, body: String)
    case custom(actionId: String, parameters: [String: String])
}

public struct RuleDefinition: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let conditions: [RuleCondition]
    public let actions: [RuleAction]
}

public struct RuleCondition: Sendable {
    public let field: String
    public let operation: String
    public let value: String
}

public struct RuleAction: Sendable {
    public let type: String
    public let parameters: [String: String]
}

public struct AIOptions: Sendable {
    public let temperature: Double?
    public let maxTokens: Int?
    public let model: String?
    public let stopSequences: [String]?
    
    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        model: String? = nil,
        stopSequences: [String]? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.model = model
        self.stopSequences = stopSequences
    }
}
