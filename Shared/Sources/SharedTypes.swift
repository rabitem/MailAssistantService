//
//  SharedTypes.swift
//  Shared
//
//  Types shared between all targets
//

import Foundation

// MARK: - Common Errors

public enum MailAssistantError: Error, LocalizedError {
    case serviceUnavailable
    case pluginNotFound
    case processingFailed(String)
    case networkError(Error)
    case invalidConfiguration
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "The mail assistant service is unavailable"
        case .pluginNotFound:
            return "The requested plugin was not found"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidConfiguration:
            return "Invalid configuration"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - Configuration

public struct AppConfiguration: Codable, Sendable {
    public var preferredAIProvider: String
    public var enableAutoSuggest: Bool
    public var suggestionDelay: TimeInterval
    public var enableDebugLogging: Bool
    public var maxSuggestions: Int
    
    public static let `default` = AppConfiguration(
        preferredAIProvider: "kimi",
        enableAutoSuggest: true,
        suggestionDelay: 1.5,
        enableDebugLogging: false,
        maxSuggestions: 3
    )
    
    public init(
        preferredAIProvider: String = "kimi",
        enableAutoSuggest: Bool = true,
        suggestionDelay: TimeInterval = 1.5,
        enableDebugLogging: Bool = false,
        maxSuggestions: Int = 3
    ) {
        self.preferredAIProvider = preferredAIProvider
        self.enableAutoSuggest = enableAutoSuggest
        self.suggestionDelay = suggestionDelay
        self.enableDebugLogging = enableDebugLogging
        self.maxSuggestions = maxSuggestions
    }
}

// MARK: - User Preferences

public struct UserPreferences: Codable, Sendable {
    public var hasCompletedOnboarding: Bool
    public var lastVersionUsed: String?
    public var usageStats: UsageStatistics
    
    public static let `default` = UserPreferences(
        hasCompletedOnboarding: false,
        lastVersionUsed: nil,
        usageStats: UsageStatistics()
    )
}

public struct UsageStatistics: Codable, Sendable {
    public var suggestionsGenerated: Int
    public var emailsAssisted: Int
    public var timeSavedMinutes: Int
    public var pluginsUsed: Int
    
    public init(
        suggestionsGenerated: Int = 0,
        emailsAssisted: Int = 0,
        timeSavedMinutes: Int = 0,
        pluginsUsed: Int = 0
    ) {
        self.suggestionsGenerated = suggestionsGenerated
        self.emailsAssisted = emailsAssisted
        self.timeSavedMinutes = timeSavedMinutes
        self.pluginsUsed = pluginsUsed
    }
}

// MARK: - Constants

public enum AppConstants {
    public static let appName = "Kimi Mail Assistant"
    public static let bundleIdentifier = "de.rabitem.MailAssistant"
    
    public enum Notifications {
        public static let serviceConnected = Notification.Name("de.rabitem.MailAssistant.serviceConnected")
        public static let serviceDisconnected = Notification.Name("de.rabitem.MailAssistant.serviceDisconnected")
        public static let suggestionsAvailable = Notification.Name("de.rabitem.MailAssistant.suggestionsAvailable")
        public static let pluginLoaded = Notification.Name("de.rabitem.MailAssistant.pluginLoaded")
    }
    
    public enum UserDefaultsKeys {
        public static let preferredAIProvider = "preferredAIProvider"
        public static let enableAutoSuggest = "enableAutoSuggest"
        public static let suggestionDelay = "suggestionDelay"
        public static let enableDebugLogging = "enableDebugLogging"
        public static let apiKeys = "apiKeys"
        public static let pluginSettings = "pluginSettings"
    }
    
    public enum XPC {
        public static let serviceName = "de.rabitem.MailAssistant.MailAssistantService"
        public static let connectionTimeout: TimeInterval = 30
    }
}

// MARK: - Logging

public enum LogLevel: Int, Comparable {
    case error = 0
    case warning = 1
    case info = 2
    case debug = 3
    case verbose = 4
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct Logger {
    public static var shared = Logger()
    
    public var minimumLevel: LogLevel = .info
    public var enableFileLogging: Bool = false
    
    public func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard level <= minimumLevel else { return }
        
        let prefix = "[\(level.prefix)] [\(sourceFileName(file)):\(line)]"
        let fullMessage = "\(prefix) \(message)"
        
        #if DEBUG
        print(fullMessage)
        #endif
        
        // Could add file logging here
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    private func sourceFileName(_ filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.last?.replacingOccurrences(of: ".swift", with: "") ?? ""
    }
}

extension LogLevel {
    var prefix: String {
        switch self {
        case .error: return "❌ ERROR"
        case .warning: return "⚠️ WARN"
        case .info: return "ℹ️ INFO"
        case .debug: return "🐛 DEBUG"
        case .verbose: return "📋 VERBOSE"
        }
    }
}

// MARK: - Extensions

public extension String {
    /// Truncates the string to the specified length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
    
    /// Returns the first line of the string
    var firstLine: String {
        return components(separatedBy: .newlines).first ?? self
    }
}

public extension Date {
    /// Returns a relative time string (e.g., "2 hours ago")
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Result Types

public enum Result<T, E: Error> {
    case success(T)
    case failure(E)
    
    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    public var value: T? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }
    
    public var error: E? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }
}
