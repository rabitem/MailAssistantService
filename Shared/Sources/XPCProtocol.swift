//
//  XPCProtocol.swift
//  Shared
//
//  Unified XPC protocol for MailAssistant service communication
//  This file is shared between MailAssistant, MailAssistantService, and MailExtension
//

import Foundation

// MARK: - XPC Service Protocol

/// Protocol exposed by the XPC service for clients to call
/// Must be @objc for NSXPCInterface compatibility
@objc public protocol MailAssistantServiceProtocol {
    
    /// Ping the service to check connectivity
    /// - Parameter reply: Callback with true if service is responsive
    @objc func ping(reply: @escaping (Bool) -> Void)
    
    /// Generate suggestions for an email
    /// - Parameters:
    ///   - email: The email content to generate suggestions for (as NSSecureCoding)
    ///   - reply: Callback with array of suggestions (as NSSecureCoding array) or error
    @objc func generateSuggestions(for email: XPCSafeEmailContent, reply: @escaping ([XPCSafeSuggestion]?, Error?) -> Void)
    
    /// Process an email with a specific plugin
    /// - Parameters:
    ///   - email: The email content to process (as NSSecureCoding)
    ///   - pluginID: The identifier of the plugin to use
    ///   - reply: Callback with process result (as NSSecureCoding) or error
    @objc func processEmail(_ email: XPCSafeEmailContent, with pluginID: String, reply: @escaping (XPCSafeProcessResult?, Error?) -> Void)
}

// MARK: - XPC Client Protocol

/// Protocol exposed by the client for the service to call back
@objc public protocol MailAssistantClientProtocol {
    
    /// Notify the client that new emails have been imported
    /// - Parameter count: Number of new emails imported
    @objc func didImportNewEmails(count: Int)
    
    /// Notify the client that the writing profile has been updated
    @objc func writingProfileDidUpdate()
    
    /// Notify the client of a plugin status change
    /// - Parameters:
    ///   - pluginID: Plugin identifier
    ///   - enabled: New enabled state
    @objc func pluginStatusDidChange(pluginID: String, enabled: Bool)
    
    /// Notify the client of a service error
    /// - Parameters:
    ///   - errorCode: Error code
    ///   - message: Error message
    @objc func didEncounterError(errorCode: Int, message: String)
}

// MARK: - NSSecureCoding Compliant Types

/// NSSecureCoding compliant version of EmailContent for XPC transmission
@objc public final class XPCSafeEmailContent: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }
    
    public let subject: String
    public let body: String
    public let sender: String
    public let recipients: [String]
    public let threadMessages: [String]?
    public let messageID: String?
    public let date: Date?
    
    public init(
        subject: String,
        body: String,
        sender: String,
        recipients: [String],
        threadMessages: [String]? = nil,
        messageID: String? = nil,
        date: Date? = nil
    ) {
        self.subject = subject
        self.body = body
        self.sender = sender
        self.recipients = recipients
        self.threadMessages = threadMessages
        self.messageID = messageID
        self.date = date
        super.init()
    }
    
    public init?(coder: NSCoder) {
        guard let subject = coder.decodeObject(of: NSString.self, forKey: "subject") as String?,
              let body = coder.decodeObject(of: NSString.self, forKey: "body") as String?,
              let sender = coder.decodeObject(of: NSString.self, forKey: "sender") as String?,
              let recipients = coder.decodeObject(of: [NSString.self], forKey: "recipients") as? [String] else {
            return nil
        }
        self.subject = subject
        self.body = body
        self.sender = sender
        self.recipients = recipients
        self.threadMessages = coder.decodeObject(of: [NSString.self], forKey: "threadMessages") as? [String]
        self.messageID = coder.decodeObject(of: NSString.self, forKey: "messageID") as String?
        self.date = coder.decodeObject(of: NSDate.self, forKey: "date") as Date?
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(subject, forKey: "subject")
        coder.encode(body, forKey: "body")
        coder.encode(sender, forKey: "sender")
        coder.encode(recipients, forKey: "recipients")
        coder.encode(threadMessages, forKey: "threadMessages")
        coder.encode(messageID, forKey: "messageID")
        coder.encode(date, forKey: "date")
    }
}

/// NSSecureCoding compliant version of Suggestion for XPC transmission
@objc public final class XPCSafeSuggestion: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }
    
    public let id: String
    public let text: String
    public let confidence: Double
    public let type: String
    public let metadata: [String: String]?
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        confidence: Double,
        type: String,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.type = type
        self.metadata = metadata
        super.init()
    }
    
    public init?(coder: NSCoder) {
        guard let id = coder.decodeObject(of: NSString.self, forKey: "id") as String?,
              let text = coder.decodeObject(of: NSString.self, forKey: "text") as String?,
              let type = coder.decodeObject(of: NSString.self, forKey: "type") as String? else {
            return nil
        }
        self.id = id
        self.text = text
        self.confidence = coder.decodeDouble(forKey: "confidence")
        self.type = type
        self.metadata = coder.decodeObject(of: [NSString.self, NSString.self], forKey: "metadata") as? [String: String]
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(text, forKey: "text")
        coder.encode(confidence, forKey: "confidence")
        coder.encode(type, forKey: "type")
        coder.encode(metadata, forKey: "metadata")
    }
}

/// NSSecureCoding compliant version of ProcessResult for XPC transmission
@objc public final class XPCSafeProcessResult: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }
    
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
        super.init()
    }
    
    public init?(coder: NSCoder) {
        self.success = coder.decodeBool(forKey: "success")
        self.output = coder.decodeObject(of: NSString.self, forKey: "output") as String?
        self.errorMessage = coder.decodeObject(of: NSString.self, forKey: "errorMessage") as String?
        self.metadata = coder.decodeObject(of: [NSString.self, NSString.self], forKey: "metadata") as? [String: String]
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(success, forKey: "success")
        coder.encode(output, forKey: "output")
        coder.encode(errorMessage, forKey: "errorMessage")
        coder.encode(metadata, forKey: "metadata")
    }
}

// MARK: - Convenience Extensions

public extension XPCSafeEmailContent {
    /// Create from PluginAPI.EmailContent
    convenience init(emailContent: EmailContent) {
        self.init(
            subject: emailContent.subject,
            body: emailContent.body,
            sender: emailContent.sender,
            recipients: emailContent.recipients,
            threadMessages: emailContent.threadMessages,
            messageID: emailContent.metadata?.messageID,
            date: emailContent.metadata?.date
        )
    }
}

public extension XPCSafeSuggestion {
    /// Create from PluginAPI.Suggestion
    convenience init(suggestion: Suggestion) {
        self.init(
            id: suggestion.id,
            text: suggestion.text,
            confidence: suggestion.confidence,
            type: suggestion.type.rawValue,
            metadata: suggestion.metadata
        )
    }
}

public extension XPCSafeProcessResult {
    /// Create from PluginAPI.ProcessResult
    convenience init(result: ProcessResult) {
        self.init(
            success: result.success,
            output: result.output,
            errorMessage: result.errorMessage,
            metadata: result.metadata
        )
    }
}
