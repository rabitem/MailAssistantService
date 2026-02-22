//
//  MailAssistantService.swift
//  MailAssistantService
//

import Foundation

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
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: MailAssistantServiceProtocol.self)
        newConnection.exportedObject = self
        
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

// MARK: - MailAssistantServiceProtocol

extension MailAssistantService: MailAssistantServiceProtocol {
    
    func ping(reply: @escaping () -> Void) {
        reply()
    }
    
    func generateSuggestions(for email: EmailContent, reply: @escaping ([Suggestion]?, Error?) -> Void) {
        Task {
            do {
                let suggestions = try await aiProvider.generateSuggestions(for: email)
                reply(suggestions, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
    
    func processEmail(_ email: EmailContent, with pluginID: String, reply: @escaping (ProcessResult?, Error?) -> Void) {
        Task {
            do {
                let result = try await pluginManager.processEmail(email, withPlugin: pluginID)
                reply(result, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
}

// MARK: - Protocol Definition

@objc(MailAssistantServiceProtocol)
protocol MailAssistantServiceProtocol {
    func ping(reply: @escaping () -> Void)
    func generateSuggestions(for email: EmailContent, reply: @escaping ([Suggestion]?, Error?) -> Void)
    func processEmail(_ email: EmailContent, with pluginID: String, reply: @escaping (ProcessResult?, Error?) -> Void)
}

// MARK: - Supporting Types

struct EmailContent: Codable {
    let subject: String
    let body: String
    let sender: String
    let recipients: [String]
    let threadMessages: [String]?
}

struct Suggestion: Codable {
    let text: String
    let confidence: Double
    let type: SuggestionType
}

enum SuggestionType: String, Codable {
    case reply
    case rewrite
    case summary
    case action
}

struct ProcessResult: Codable {
    let success: Bool
    let output: String?
    let errorMessage: String?
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
