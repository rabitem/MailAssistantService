//
//  XPCServiceManager.swift
//  KimiMailAssistant
//

import Foundation

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
        
        let newConnection = NSXPCConnection(serviceName: "com.rabitem.KimiMailAssistant.MailAssistantService")
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
        serviceProxy = newConnection.remoteObjectProxy as? MailAssistantServiceProtocol
        serviceProxy?.ping { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = true
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
        serviceProxy?.generateSuggestions(for: email) { suggestions, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error generating suggestions: \(error)")
                    completion([])
                } else {
                    completion(suggestions ?? [])
                }
            }
        }
    }
}

// MARK: - Protocol (defined in Shared)

@objc(MailAssistantServiceProtocol)
protocol MailAssistantServiceProtocol {
    func ping(reply: @escaping () -> Void)
    func generateSuggestions(for email: EmailContent, reply: @escaping ([Suggestion]?, Error?) -> Void)
    func processEmail(_ email: EmailContent, with pluginID: String, reply: @escaping (ProcessResult?, Error?) -> Void)
}

// MARK: - Data Models

struct EmailContent: Codable {
    let subject: String
    let body: String
    let sender: String
    let recipients: [String]
    let threadMessages: [String]?
}

struct Suggestion: Codable, Identifiable {
    let id = UUID()
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
