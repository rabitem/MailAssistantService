//
//  XPCInterface.swift
//  MailAssistantService
//
//  Protocol definitions for XPC communication between main app and service
//

import Foundation

// MARK: - Service Protocol (Main App → Service)

/// Protocol exposed by the XPC service for the main app to call
@objc protocol MailAssistantServiceProtocol {
    
    // MARK: - Response Generation
    
    /// Generate an AI response for an email
    /// - Parameters:
    ///   - emailID: Unique identifier of the email to respond to
    ///   - style: Writing style profile to use (e.g., "professional", "friendly", "concise")
    ///   - completion: Callback with generated response text or error
    func generateResponse(for emailID: String, style: String, completion: @escaping (String?, Error?) -> Void)
    
    /// Generate a quick reply suggestion
    /// - Parameters:
    ///   - emailID: Unique identifier of the email
    ///   - tone: Desired tone (optional, uses default if not specified)
    ///   - completion: Callback with suggestion or error
    func generateQuickReply(for emailID: String, tone: String?, completion: @escaping (String?, Error?) -> Void)
    
    // MARK: - Writing Profile
    
    /// Get the current writing profile/style analysis
    /// - Parameter completion: Callback with profile data (JSON encoded) or error
    func getWritingProfile(completion: @escaping (Data?, Error?) -> Void)
    
    /// Update the writing profile with new sample emails
    /// - Parameters:
    ///   - sampleIDs: Array of email IDs to use as samples
    ///   - completion: Callback with success flag or error
    func updateWritingProfile(with sampleIDs: [String], completion: @escaping (Bool, Error?) -> Void)
    
    // MARK: - Email Search & Management
    
    /// Search emails using natural language query
    /// - Parameters:
    ///   - query: Natural language search query
    ///   - completion: Callback with array of email data (JSON encoded) or error
    func searchEmails(query: String, completion: @escaping ([Data]?, Error?) -> Void)
    
    /// Get thread context for an email
    /// - Parameters:
    ///   - emailID: Email ID to get thread for
    ///   - completion: Callback with thread data or error
    func getThreadContext(for emailID: String, completion: @escaping (Data?, Error?) -> Void)
    
    // MARK: - Plugin Management
    
    /// Enable a plugin by ID
    /// - Parameters:
    ///   - id: Plugin identifier
    ///   - completion: Callback with success flag or error
    func enablePlugin(id: String, completion: @escaping (Bool, Error?) -> Void)
    
    /// Disable a plugin by ID
    /// - Parameters:
    ///   - id: Plugin identifier
    ///   - completion: Callback with success flag or error
    func disablePlugin(id: String, completion: @escaping (Bool, Error?) -> Void)
    
    /// Get status of all plugins
    /// - Parameter completion: Callback with plugin status data (JSON encoded) or error
    func getPluginStatus(completion: @escaping (Data?, Error?) -> Void)
    
    /// Get available plugins list
    /// - Parameter completion: Callback with plugin list data or error
    func getAvailablePlugins(completion: @escaping (Data?, Error?) -> Void)
    
    // MARK: - Service Health & Info
    
    /// Get service version and health info
    /// - Parameter completion: Callback with version info or error
    func getServiceInfo(completion: @escaping (Data?, Error?) -> Void)
    
    /// Ping the service to check connectivity
    /// - Parameter completion: Callback with true if service is responsive
    func ping(completion: @escaping (Bool) -> Void)
}

// MARK: - Client Protocol (Service → Main App)

/// Protocol exposed by the main app for the service to call back
@objc protocol MailAssistantClientProtocol {
    
    /// Notify the client that new emails have been imported
    /// - Parameter count: Number of new emails imported
    func didImportNewEmails(count: Int)
    
    /// Notify the client that the writing profile has been updated
    func writingProfileDidUpdate()
    
    /// Notify the client of a plugin status change
    /// - Parameters:
    ///   - pluginID: Plugin identifier
    ///   - enabled: New enabled state
    func pluginStatusDidChange(pluginID: String, enabled: Bool)
    
    /// Request authentication from the client
    /// - Parameter completion: Callback with auth token or nil if cancelled
    func requestAuthentication(completion: @escaping (String?) -> Void)
    
    /// Notify the client of a service error
    /// - Parameters:
    ///   - errorCode: Error code
    ///   - message: Error message
    func didEncounterError(errorCode: Int, message: String)
}

// MARK: - XPC Error Types

/// Errors that can occur during XPC communication
enum XPCServiceError: Error, LocalizedError {
    case serviceNotAvailable
    case invalidEmailID
    case invalidStyleProfile
    case generationFailed(reason: String)
    case searchFailed(reason: String)
    case pluginNotFound(id: String)
    case pluginOperationFailed(id: String, reason: String)
    case databaseError
    case unauthorized
    case invalidRequest
    case internalError
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .serviceNotAvailable:
            return "The mail assistant service is not available"
        case .invalidEmailID:
            return "The specified email ID is invalid or not found"
        case .invalidStyleProfile:
            return "The specified writing style profile is invalid"
        case .generationFailed(let reason):
            return "Failed to generate response: \(reason)"
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        case .pluginNotFound(let id):
            return "Plugin '\(id)' not found"
        case .pluginOperationFailed(let id, let reason):
            return "Plugin operation failed for '\(id)': \(reason)"
        case .databaseError:
            return "A database error occurred"
        case .unauthorized:
            return "Not authorized to perform this operation"
        case .invalidRequest:
            return "The request is invalid"
        case .internalError:
            return "An internal service error occurred"
        case .timeout:
            return "The operation timed out"
        }
    }
    
    /// NSError-compatible error code for XPC
    var errorCode: Int {
        switch self {
        case .serviceNotAvailable: return 1001
        case .invalidEmailID: return 1002
        case .invalidStyleProfile: return 1003
        case .generationFailed: return 1004
        case .searchFailed: return 1005
        case .pluginNotFound: return 1006
        case .pluginOperationFailed: return 1007
        case .databaseError: return 1008
        case .unauthorized: return 1009
        case .invalidRequest: return 1010
        case .internalError: return 1011
        case .timeout: return 1012
        }
    }
}

// MARK: - XPC Codable Types

/// Service version information
struct ServiceInfo: Codable {
    let version: String
    let buildNumber: String
    let startupTime: Date
    let uptime: TimeInterval
    let activeConnections: Int
    let databaseSize: UInt64
    let lastEmailImport: Date?
    let isHealthy: Bool
    
    enum CodingKeys: String, CodingKey {
        case version
        case buildNumber
        case startupTime
        case uptime
        case activeConnections
        case databaseSize
        case lastEmailImport
        case isHealthy
    }
}

/// Plugin status information
struct PluginStatus: Codable {
    let id: String
    let name: String
    let version: String
    let isEnabled: Bool
    let isLoaded: Bool
    let lastError: String?
    let metadata: [String: String]
}

/// Search result structure
struct SearchResult: Codable {
    let emailID: String
    let subject: String
    let sender: String
    let date: Date
    let snippet: String
    let relevanceScore: Double
    let threadID: String?
}

/// Writing profile data
struct WritingProfileData: Codable {
    let profileID: String
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let sampleCount: Int
    let characteristics: [String: Double]
    let commonPhrases: [String]
    let averageResponseLength: Int
    let preferredGreetings: [String]
    let preferredSignoffs: [String]
}
