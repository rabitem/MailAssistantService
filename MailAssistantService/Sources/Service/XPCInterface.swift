//
//  XPCInterface.swift
//  MailAssistantService
//
//  Protocol definitions for XPC communication between main app and service
//  Note: Main protocol definitions are now in Shared/Sources/XPCProtocol.swift
//

import Foundation
import Shared

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
