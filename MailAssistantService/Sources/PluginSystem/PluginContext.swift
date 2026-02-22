import Foundation
import PluginAPI

/// Implementation of PluginContext passed to plugins
@preconcurrency
public actor PluginContextImpl: PluginContext {
    public let manifest: PluginManifest
    public let eventBus: EventBus
    public let storage: PluginStorage
    public let logger: PluginLogger
    public let permissions: PermissionProvider
    
    private let aiServiceProvider: AIServiceProvider?
    private let emailServiceProvider: EmailServiceProvider?
    private let networkServiceProvider: NetworkServiceProvider?
    private var settingsStorage: [String: Any]
    
    public var aiService: AIServiceProvider? { aiServiceProvider }
    public var emailService: EmailServiceProvider? { emailServiceProvider }
    public var networkService: NetworkServiceProvider? { networkServiceProvider }
    public var settings: [String: Any] { settingsStorage }
    
    init(
        manifest: PluginManifest,
        eventBus: EventBus,
        storage: PluginStorage,
        logger: PluginLogger,
        permissions: PermissionProvider,
        aiService: AIServiceProvider? = nil,
        emailService: EmailServiceProvider? = nil,
        networkService: NetworkServiceProvider? = nil,
        settings: [String: Any] = [:]
    ) {
        self.manifest = manifest
        self.eventBus = eventBus
        self.storage = storage
        self.logger = logger
        self.permissions = permissions
        self.aiServiceProvider = aiService
        self.emailServiceProvider = emailService
        self.networkServiceProvider = networkService
        self.settingsStorage = settings
    }
    
    /// Update settings
    func updateSettings(_ newSettings: [String: Any]) {
        settingsStorage = newSettings
    }
}

/// Logger implementation for plugins
public struct PluginLoggerImpl: PluginLogger {
    private let pluginId: PluginID
    private let logHandler: (LogEntry) -> Void
    
    public init(pluginId: PluginID, logHandler: @escaping (LogEntry) -> Void) {
        self.pluginId = pluginId
        self.logHandler = logHandler
    }
    
    public func debug(_ message: String, file: String, line: Int, function: String) {
        logHandler(LogEntry(
            level: .debug,
            pluginId: pluginId,
            message: message,
            errorMessage: nil,
            file: file,
            line: line,
            function: function,
            timestamp: Date()
        ))
    }
    
    public func info(_ message: String, file: String, line: Int, function: String) {
        logHandler(LogEntry(
            level: .info,
            pluginId: pluginId,
            message: message,
            errorMessage: nil,
            file: file,
            line: line,
            function: function,
            timestamp: Date()
        ))
    }
    
    public func warning(_ message: String, file: String, line: Int, function: String) {
        logHandler(LogEntry(
            level: .warning,
            pluginId: pluginId,
            message: message,
            errorMessage: nil,
            file: file,
            line: line,
            function: function,
            timestamp: Date()
        ))
    }
    
    public func error(_ message: String, error: Error?, file: String, line: Int, function: String) {
        logHandler(LogEntry(
            level: .error,
            pluginId: pluginId,
            message: message,
            errorMessage: error?.localizedDescription,
            file: file,
            line: line,
            function: function,
            timestamp: Date()
        ))
    }
}

/// Log entry model
public struct LogEntry: Sendable {
    public let level: LogLevel
    public let pluginId: PluginID
    public let message: String
    public let errorMessage: String?
    public let file: String
    public let line: Int
    public let function: String
    public let timestamp: Date
}

public enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// Storage implementation for plugins
public actor PluginStorageImpl: PluginStorage {
    private let pluginId: PluginID
    private let baseDirectory: URL
    private var cache: [String: Data] = [:]
    
    public init(pluginId: PluginID, baseDirectory: URL) {
        self.pluginId = pluginId
        self.baseDirectory = baseDirectory.appendingPathComponent(pluginId.rawValue, isDirectory: true)
        
        // Create storage directory if needed
        try? FileManager.default.createDirectory(
            at: self.baseDirectory,
            withIntermediateDirectories: true
        )
    }
    
    public func set<T: Codable & Sendable>(_ value: T, forKey key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        
        let fileURL = baseDirectory.appendingPathComponent("\(key).json")
        try data.write(to: fileURL, options: .atomic)
        cache[key] = data
    }
    
    public func get<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        // Check cache first
        if let cachedData = cache[key] {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: cachedData)
        }
        
        let fileURL = baseDirectory.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        cache[key] = data
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    public func remove(forKey key: String) async throws {
        cache.removeValue(forKey: key)
        let fileURL = baseDirectory.appendingPathComponent("\(key).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
    
    public var allKeys: [String] {
        get async {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: nil
            ) else {
                return []
            }
            
            return files
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
        }
    }
    
    public func clear() async throws {
        cache.removeAll()
        
        if FileManager.default.fileExists(atPath: baseDirectory.path) {
            try FileManager.default.removeItem(at: baseDirectory)
            try FileManager.default.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}
