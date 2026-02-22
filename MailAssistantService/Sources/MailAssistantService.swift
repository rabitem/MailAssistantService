//
//  MailAssistantService.swift
//  MailAssistantService
//

import Foundation
import Shared

/// XPC Service that provides AI-powered email assistance
class MailAssistantService: NSObject, NSXPCListenerDelegate {
    
    // MARK: - Properties
    
    private var listener: NSXPCListener?
    private var pluginManager: PluginManager
    private var aiProvider: AIProvider
    
    // MARK: - Initialization
    
    override init() {
        self.pluginManager = PluginManager()
        self.aiProvider = AIProvider()
        super.init()
    }
    
    // MARK: - Service Lifecycle
    
    func run() {
        // Create the XPC listener
        listener = NSXPCListener.service()
        listener?.delegate = self
        listener?.resume()
        
        NSLog("MailAssistantService: XPC service started")
        
        // Initialize plugins
        pluginManager.loadPlugins()
    }
    
    func stop() {
        listener?.invalidate()
        NSLog("MailAssistantService: XPC service stopped")
    }
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure the connection with the shared protocol
        newConnection.exportedInterface = NSXPCInterface(with: MailAssistantServiceProtocol.self)
        newConnection.exportedObject = self
        
        // Configure the remote interface for callbacks
        newConnection.remoteObjectInterface = NSXPCInterface(with: MailAssistantClientProtocol.self)
        
        // Set up handlers
        newConnection.invalidationHandler = {
            NSLog("MailAssistantService: Connection invalidated")
        }
        
        newConnection.interruptionHandler = {
            NSLog("MailAssistantService: Connection interrupted")
        }
        
        newConnection.resume()
        return true
    }
}

// MARK: - MailAssistantServiceProtocol Implementation

extension MailAssistantService: MailAssistantServiceProtocol {
    
    func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }
    
    func generateSuggestions(for email: XPCSafeEmailContent, reply: @escaping ([XPCSafeSuggestion]?, Error?) -> Void) {
        Task {
            do {
                // Convert XPCSafeEmailContent to EmailContent for internal processing
                let emailContent = EmailContent(
                    subject: email.subject,
                    body: email.body,
                    sender: email.sender,
                    recipients: email.recipients,
                    threadMessages: email.threadMessages,
                    metadata: EmailMetadata(
                        messageID: email.messageID,
                        date: email.date,
                        importance: nil,
                        attachments: nil
                    )
                )
                
                let suggestions = try await aiProvider.generateSuggestions(for: emailContent)
                
                // Convert suggestions to XPCSafeSuggestion
                let safeSuggestions = suggestions.map { suggestion in
                    XPCSafeSuggestion(suggestion: suggestion)
                }
                
                reply(safeSuggestions, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
    
    func processEmail(_ email: XPCSafeEmailContent, with pluginID: String, reply: @escaping (XPCSafeProcessResult?, Error?) -> Void) {
        Task {
            do {
                // Convert XPCSafeEmailContent to EmailContent for internal processing
                let emailContent = EmailContent(
                    subject: email.subject,
                    body: email.body,
                    sender: email.sender,
                    recipients: email.recipients,
                    threadMessages: email.threadMessages,
                    metadata: EmailMetadata(
                        messageID: email.messageID,
                        date: email.date,
                        importance: nil,
                        attachments: nil
                    )
                )
                
                let result = try await pluginManager.processEmail(emailContent, withPlugin: pluginID)
                
                // Convert result to XPCSafeProcessResult
                let safeResult = XPCSafeProcessResult(result: result)
                
                reply(safeResult, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
}

// MARK: - Plugin Manager

class PluginManager {
    private var plugins: [String: MailPlugin] = [:]
    
    func loadPlugins() {
        // Load built-in and user plugins
        NSLog("MailAssistantService: Loading plugins...")
    }
    
    func processEmail(_ email: EmailContent, withPlugin pluginID: String) async throws -> ProcessResult {
        guard let plugin = plugins[pluginID] else {
            throw PluginError.pluginNotFound
        }
        return try await plugin.process(email)
    }
}

// MARK: - AI Provider

class AIProvider {
    func generateSuggestions(for email: EmailContent) async throws -> [Suggestion] {
        // Connect to configured AI provider (Kimi, OpenAI, etc.)
        // This is a placeholder implementation
        return []
    }
}

// MARK: - Plugin Protocol

protocol MailPlugin {
    var id: String { get }
    var name: String { get }
    func process(_ email: EmailContent) async throws -> ProcessResult
}

enum PluginError: Error {
    case pluginNotFound
    case processingFailed
}
