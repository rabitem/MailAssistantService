//
//  XPCServiceManager.swift
//  MailAssistant
//

import Foundation
import Shared

/// Manages the connection to the MailAssistant XPC Service
class XPCServiceManager: ObservableObject {
    static let shared = XPCServiceManager()
    
    @Published var isConnected = false
    
    private var connection: NSXPCConnection?
    private var serviceProxy: MailAssistantServiceProtocol?
    
    private init() {}
    
    /// Establishes connection to the XPC service
    func connect() {
        guard connection == nil else { return }
        
        let newConnection = NSXPCConnection(serviceName: AppConstants.XPC.serviceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: MailAssistantServiceProtocol.self)
        
        newConnection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.connection = nil
            }
        }
        
        newConnection.interruptionHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        newConnection.resume()
        connection = newConnection
        
        // Test the connection
        serviceProxy = newConnection.remoteObjectProxyWithErrorHandler { [weak self] error in
            DispatchQueue.main.async {
                print("XPC Connection error: \(error)")
                self?.isConnected = false
            }
        } as? MailAssistantServiceProtocol
        
        serviceProxy?.ping { [weak self] success in
            DispatchQueue.main.async {
                self?.isConnected = success
            }
        }
    }
    
    /// Disconnects from the XPC service
    func disconnect() {
        connection?.invalidate()
        connection = nil
        serviceProxy = nil
        isConnected = false
    }
    
    /// Returns the service proxy for making XPC calls
    func getServiceProxy() -> MailAssistantServiceProtocol? {
        return serviceProxy
    }
    
    /// Requests email suggestions from the service
    func requestSuggestions(for email: EmailContent, completion: @escaping ([Suggestion]) -> Void) {
        // Convert EmailContent to XPCSafeEmailContent for transmission
        let safeEmail = XPCSafeEmailContent(emailContent: email)
        
        serviceProxy?.generateSuggestions(for: safeEmail) { safeSuggestions, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error generating suggestions: \(error)")
                    completion([])
                } else if let safeSuggestions = safeSuggestions {
                    // Convert XPCSafeSuggestion back to Suggestion
                    let suggestions = safeSuggestions.map { safe in
                        Suggestion(
                            id: safe.id,
                            text: safe.text,
                            confidence: safe.confidence,
                            type: SuggestionType(rawValue: safe.type) ?? .reply,
                            metadata: safe.metadata
                        )
                    }
                    completion(suggestions)
                } else {
                    completion([])
                }
            }
        }
    }
    
    /// Process an email with a specific plugin
    func processEmail(_ email: EmailContent, with pluginID: String, completion: @escaping (ProcessResult?) -> Void) {
        // Convert EmailContent to XPCSafeEmailContent for transmission
        let safeEmail = XPCSafeEmailContent(emailContent: email)
        
        serviceProxy?.processEmail(safeEmail, with: pluginID) { safeResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error processing email: \(error)")
                    completion(nil)
                } else if let safeResult = safeResult {
                    // Convert XPCSafeProcessResult back to ProcessResult
                    let result = ProcessResult(
                        success: safeResult.success,
                        output: safeResult.output,
                        errorMessage: safeResult.errorMessage,
                        metadata: safeResult.metadata
                    )
                    completion(result)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
