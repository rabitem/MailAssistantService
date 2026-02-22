//
//  PluginAPI.swift
//  PluginAPI
//
//  Public SDK for creating Kimi Mail Assistant plugins
//

import Foundation

// MARK: - Plugin Protocol

/// Protocol that all Mail Assistant plugins must conform to
public protocol MailAssistantPlugin: AnyObject {
    /// Unique identifier for the plugin
    static var pluginIdentifier: String { get }
    
    /// Human-readable name
    static var pluginName: String { get }
    
    /// Plugin version (semantic versioning)
    static var pluginVersion: String { get }
    
    /// Plugin description
    static var pluginDescription: String { get }
    
    /// Plugin author
    static var pluginAuthor: String { get }
    
    /// Initialize the plugin
    init()
    
    /// Called when the plugin is loaded
    func pluginDidLoad()
    
    /// Called when the plugin is unloaded
    func pluginWillUnload()
}

// MARK: - Processing Plugin

/// Plugin that processes email content
public protocol EmailProcessingPlugin: MailAssistantPlugin {
    /// Process an email and return a result
    func process(_ email: EmailContent) async throws -> ProcessResult
    
    /// Supported processing types
    var supportedTypes: [ProcessingType] { get }
}

/// Plugin that provides AI suggestions
public protocol SuggestionPlugin: MailAssistantPlugin {
    /// Generate suggestions for an email
    func generateSuggestions(
        for email: EmailContent,
        context: SuggestionContext
    ) async throws -> [Suggestion]
    
    /// Supported suggestion types
    var suggestionTypes: [SuggestionType] { get }
}

/// Plugin that provides custom actions
public protocol ActionPlugin: MailAssistantPlugin {
    /// Available actions
    var actions: [PluginAction] { get }
    
    /// Perform an action on an email
    func performAction(
        _ actionID: String,
        on email: EmailContent
    ) async throws -> ActionResult
}

// MARK: - Data Models

/// Represents an email message
public struct EmailContent: Codable, Sendable {
    public let subject: String
    public let body: String
    public let sender: String
    public let recipients: [String]
    public let threadMessages: [String]?
    public let metadata: EmailMetadata?
    
    public init(
        subject: String,
        body: String,
        sender: String,
        recipients: [String],
        threadMessages: [String]? = nil,
        metadata: EmailMetadata? = nil
    ) {
        self.subject = subject
        self.body = body
        self.sender = sender
        self.recipients = recipients
        self.threadMessages = threadMessages
        self.metadata = metadata
    }
}

/// Additional email metadata
public struct EmailMetadata: Codable, Sendable {
    public let messageID: String?
    public let date: Date?
    public let importance: Importance?
    public let attachments: [AttachmentInfo]?
    
    public init(
        messageID: String? = nil,
        date: Date? = nil,
        importance: Importance? = nil,
        attachments: [AttachmentInfo]? = nil
    ) {
        self.messageID = messageID
        self.date = date
        self.importance = importance
        self.attachments = attachments
    }
}

/// Attachment information
public struct AttachmentInfo: Codable, Sendable {
    public let filename: String
    public let mimeType: String
    public let size: Int
    
    public init(filename: String, mimeType: String, size: Int) {
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
    }
}

/// Email importance level
public enum Importance: String, Codable, Sendable {
    case low
    case normal
    case high
}

// MARK: - Processing Types

public enum ProcessingType: String, Codable, Sendable {
    case summarize
    case translate
    case classify
    case extract
    case analyze
}

public struct ProcessResult: Codable, Sendable {
    public let success: Bool
    public let output: String?
    public let errorMessage: String?
    public let metadata: [String: String]?
    
    public init(
        success: Bool,
        output: String? = nil,
        errorMessage: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.success = success
        self.output = output
        self.errorMessage = errorMessage
        self.metadata = metadata
    }
    
    public static func success(_ output: String, metadata: [String: String]? = nil) -> ProcessResult {
        ProcessResult(success: true, output: output, metadata: metadata)
    }
    
    public static func failure(_ error: String) -> ProcessResult {
        ProcessResult(success: false, errorMessage: error)
    }
}

// MARK: - Suggestions

public struct SuggestionContext: Codable, Sendable {
    public let composeType: ComposeType
    public let cursorPosition: Int?
    public let selectedText: String?
    
    public init(
        composeType: ComposeType,
        cursorPosition: Int? = nil,
        selectedText: String? = nil
    ) {
        self.composeType = composeType
        self.cursorPosition = cursorPosition
        self.selectedText = selectedText
    }
}

public enum ComposeType: String, Codable, Sendable {
    case newMessage
    case reply
    case replyAll
    case forward
}

public struct Suggestion: Codable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let confidence: Double
    public let type: SuggestionType
    public let metadata: [String: String]?
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        confidence: Double,
        type: SuggestionType,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.type = type
        self.metadata = metadata
    }
}

public enum SuggestionType: String, Codable, Sendable {
    case completion
    case rewrite
    case reply
    case summary
    case action
}

// MARK: - Actions

public struct PluginAction: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String?
    public let icon: String?
    public let shortcut: KeyboardShortcut?
    
    public init(
        id: String,
        title: String,
        description: String? = nil,
        icon: String? = nil,
        shortcut: KeyboardShortcut? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.shortcut = shortcut
    }
}

public struct KeyboardShortcut: Codable, Sendable {
    public let key: String
    public let modifiers: [ModifierKey]
    
    public init(key: String, modifiers: [ModifierKey]) {
        self.key = key
        self.modifiers = modifiers
    }
}

public enum ModifierKey: String, Codable, Sendable {
    case command
    case option
    case control
    case shift
}

public struct ActionResult: Codable, Sendable {
    public let success: Bool
    public let message: String?
    public let output: String?
    public let shouldRefresh: Bool
    
    public init(
        success: Bool,
        message: String? = nil,
        output: String? = nil,
        shouldRefresh: Bool = false
    ) {
        self.success = success
        self.message = message
        self.output = output
        self.shouldRefresh = shouldRefresh
    }
}

// MARK: - Plugin Errors

public enum PluginError: Error {
    case notImplemented
    case processingFailed(String)
    case invalidInput
    case configurationMissing
    case apiError(String)
    case cancelled
}

// MARK: - Plugin Registry

/// Registry for managing plugins
public final class PluginRegistry {
    public static let shared = PluginRegistry()
    
    private var plugins: [String: MailAssistantPlugin.Type] = [:]
    
    private init() {}
    
    /// Register a plugin
    public func register(_ pluginType: MailAssistantPlugin.Type) {
        plugins[pluginType.pluginIdentifier] = pluginType
    }
    
    /// Get a registered plugin type
    public func getPluginType(identifier: String) -> MailAssistantPlugin.Type? {
        return plugins[identifier]
    }
    
    /// Get all registered plugins
    public func allPlugins() -> [MailAssistantPlugin.Type] {
        return Array(plugins.values)
    }
    
    /// Create an instance of a plugin
    public func createInstance(identifier: String) -> MailAssistantPlugin? {
        guard let pluginType = plugins[identifier] else { return nil }
        return pluginType.init()
    }
}

// MARK: - Plugin Capabilities

/// Capabilities that a plugin can advertise
public struct PluginCapabilities: OptionSet, Codable, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let processing = PluginCapabilities(rawValue: 1 << 0)
    public static let suggestions = PluginCapabilities(rawValue: 1 << 1)
    public static let actions = PluginCapabilities(rawValue: 1 << 2)
    public static let composeIntegration = PluginCapabilities(rawValue: 1 << 3)
    public static let readIntegration = PluginCapabilities(rawValue: 1 << 4)
}

// MARK: - Plugin Manifest

/// Manifest describing a plugin
public struct PluginManifest: Codable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String
    public let description: String
    public let author: String
    public let capabilities: PluginCapabilities
    public let minimumAppVersion: String
    public let permissions: [PluginPermission]
    
    public init(
        identifier: String,
        name: String,
        version: String,
        description: String,
        author: String,
        capabilities: PluginCapabilities,
        minimumAppVersion: String,
        permissions: [PluginPermission]
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.capabilities = capabilities
        self.minimumAppVersion = minimumAppVersion
        self.permissions = permissions
    }
}

public enum PluginPermission: String, Codable, Sendable {
    case readEmailContent
    case modifyEmailContent
    case sendEmail
    case accessContacts
    case networkAccess
    case fileSystemAccess
}
