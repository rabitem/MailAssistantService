import Foundation
import PluginAPI

/// Sandbox configuration for a plugin
public struct SandboxConfiguration: Sendable {
    /// Maximum memory allowed (bytes)
    public let maxMemory: UInt64
    
    /// Maximum file system storage (bytes)
    public let maxStorage: UInt64
    
    /// Maximum network request size (bytes)
    public let maxNetworkRequestSize: UInt64
    
    /// Allowed network hosts (empty = all allowed if network permission granted)
    public let allowedHosts: [String]
    
    /// Blocked network hosts
    public let blockedHosts: [String]
    
    /// Allowed file system paths (outside plugin storage)
    public let allowedPaths: [String]
    
    /// Maximum execution time for background tasks (seconds)
    public let maxBackgroundTaskDuration: TimeInterval
    
    /// Maximum concurrent network requests
    public let maxConcurrentNetworkRequests: Int
    
    public init(
        maxMemory: UInt64 = 100 * 1024 * 1024,           // 100 MB
        maxStorage: UInt64 = 50 * 1024 * 1024,           // 50 MB
        maxNetworkRequestSize: UInt64 = 10 * 1024 * 1024, // 10 MB
        allowedHosts: [String] = [],
        blockedHosts: [String] = [],
        allowedPaths: [String] = [],
        maxBackgroundTaskDuration: TimeInterval = 300,   // 5 minutes
        maxConcurrentNetworkRequests: Int = 10
    ) {
        self.maxMemory = maxMemory
        self.maxStorage = maxStorage
        self.maxNetworkRequestSize = maxNetworkRequestSize
        self.allowedHosts = allowedHosts
        self.blockedHosts = blockedHosts
        self.allowedPaths = allowedPaths
        self.maxBackgroundTaskDuration = maxBackgroundTaskDuration
        self.maxConcurrentNetworkRequests = maxConcurrentNetworkRequests
    }
    
    /// Default configuration for built-in plugins
    public static let `default` = SandboxConfiguration()
    
    /// Restrictive configuration for external plugins
    public static let restrictive = SandboxConfiguration(
        maxMemory: 50 * 1024 * 1024,
        maxStorage: 25 * 1024 * 1024,
        maxNetworkRequestSize: 5 * 1024 * 1024,
        maxBackgroundTaskDuration: 60,
        maxConcurrentNetworkRequests: 5
    )
}

/// Plugin sandbox for security isolation
public actor PluginSandbox {
    private let pluginId: PluginID
    private let configuration: SandboxConfiguration
    private let permissionProvider: PermissionProvider
    
    /// Current memory usage
    private var currentMemoryUsage: UInt64 = 0
    
    /// Current storage usage
    private var currentStorageUsage: UInt64 = 0
    
    /// Active network requests
    private var activeNetworkRequests: Int = 0
    
    /// Background task tracker
    private var backgroundTasks: Set<String> = []
    
    /// Logger
    private let logger: ((String) -> Void)?
    
    /// Violation handler
    private let onViolation: ((SandboxViolation) -> Void)?
    
    public init(
        pluginId: PluginID,
        configuration: SandboxConfiguration,
        permissionProvider: PermissionProvider,
        logger: ((String) -> Void)? = nil,
        onViolation: ((SandboxViolation) -> Void)? = nil
    ) {
        self.pluginId = pluginId
        self.configuration = configuration
        self.permissionProvider = permissionProvider
        self.logger = logger
        self.onViolation = onViolation
    }
    
    // MARK: - Memory Management
    
    /// Allocate memory in the sandbox
    public func allocateMemory(_ bytes: UInt64) -> Bool {
        let newUsage = currentMemoryUsage + bytes
        
        guard newUsage <= configuration.maxMemory else {
            reportViolation(.memoryLimitExceeded(
                requested: bytes,
                current: currentMemoryUsage,
                limit: configuration.maxMemory
            ))
            return false
        }
        
        currentMemoryUsage = newUsage
        return true
    }
    
    /// Deallocate memory from the sandbox
    public func deallocateMemory(_ bytes: UInt64) {
        currentMemoryUsage = min(currentMemoryUsage, bytes)
    }
    
    /// Get current memory usage
    public var memoryUsage: UInt64 {
        currentMemoryUsage
    }
    
    // MARK: - Storage Management
    
    /// Check if storage operation is allowed
    public func canUseStorage(_ bytes: UInt64) -> Bool {
        let newUsage = currentStorageUsage + bytes
        
        if newUsage > configuration.maxStorage {
            reportViolation(.storageLimitExceeded(
                requested: bytes,
                current: currentStorageUsage,
                limit: configuration.maxStorage
            ))
            return false
        }
        
        return true
    }
    
    /// Update storage usage
    public func updateStorageUsage(_ bytes: UInt64) {
        currentStorageUsage = bytes
    }
    
    /// Get current storage usage
    public var storageUsage: UInt64 {
        currentStorageUsage
    }
    
    // MARK: - Network Access Control
    
    /// Check if network access is allowed for a URL
    public func canMakeNetworkRequest(to url: URL) async -> Bool {
        // Check if network permission is granted
        guard await permissionProvider.hasPermission(.networkAccess) else {
            reportViolation(.permissionDenied(.networkAccess))
            return false
        }
        
        // Check concurrent request limit
        guard activeNetworkRequests < configuration.maxConcurrentNetworkRequests else {
            reportViolation(.tooManyConcurrentRequests(
                current: activeNetworkRequests,
                limit: configuration.maxConcurrentNetworkRequests
            ))
            return false
        }
        
        // Check host restrictions
        guard let host = url.host else {
            return false
        }
        
        // Check blocked hosts
        if configuration.blockedHosts.contains(host) {
            reportViolation(.blockedHost(host))
            return false
        }
        
        // Check allowed hosts (if specified, must be in list)
        if !configuration.allowedHosts.isEmpty && !configuration.allowedHosts.contains(host) {
            reportViolation(.hostNotAllowed(host))
            return false
        }
        
        return true
    }
    
    /// Track network request start
    public func beginNetworkRequest() {
        activeNetworkRequests += 1
    }
    
    /// Track network request end
    public func endNetworkRequest() {
        activeNetworkRequests = max(0, activeNetworkRequests - 1)
    }
    
    /// Check request size
    public func validateRequestSize(_ size: UInt64) -> Bool {
        guard size <= configuration.maxNetworkRequestSize else {
            reportViolation(.requestSizeExceeded(
                size: size,
                limit: configuration.maxNetworkRequestSize
            ))
            return false
        }
        return true
    }
    
    // MARK: - File System Sandbox
    
    /// Check if file access is allowed
    public func canAccessFile(at path: String, write: Bool = false) async -> Bool {
        // Check file system permission for writes outside plugin storage
        if write {
            guard await permissionProvider.hasPermission(.fileSystemAccess) else {
                reportViolation(.permissionDenied(.fileSystemAccess))
                return false
            }
        }
        
        // Check allowed paths
        let normalizedPath = (path as NSString).standardizingPath
        
        // Always allow access to plugin's own storage
        if normalizedPath.contains("/PluginStorage/\(pluginId.rawValue)/") {
            return true
        }
        
        // Check against allowed paths
        for allowedPath in configuration.allowedPaths {
            if normalizedPath.hasPrefix(allowedPath) {
                return true
            }
        }
        
        if write {
            reportViolation(.fileSystemAccessDenied(path: path))
        }
        
        return !write // Allow reads to system paths, but not writes
    }
    
    /// Get sandboxed file URL
    public func sandboxedFileURL(for relativePath: String) -> URL {
        // All file access should go through plugin storage
        let baseDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("KimiMail/PluginStorage/\(pluginId.rawValue)", isDirectory: true)
        
        // Sanitize the path to prevent directory traversal
        let sanitizedPath = relativePath
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "//", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        return baseDir?.appendingPathComponent(sanitizedPath) ?? URL(fileURLWithPath: sanitizedPath)
    }
    
    // MARK: - Background Task Control
    
    /// Register a background task
    public func registerBackgroundTask(id: String) -> Bool {
        guard backgroundTasks.count < 5 else { // Max 5 concurrent background tasks
            reportViolation(.tooManyBackgroundTasks)
            return false
        }
        
        backgroundTasks.insert(id)
        
        // Schedule automatic cleanup
        Task {
            try? await Task.sleep(nanoseconds: UInt64(configuration.maxBackgroundTaskDuration * 1_000_000_000))
            await unregisterBackgroundTask(id: id)
            logger?("[Sandbox] Background task \(id) timed out")
        }
        
        return true
    }
    
    /// Unregister a background task
    public func unregisterBackgroundTask(id: String) {
        backgroundTasks.remove(id)
    }
    
    /// Cancel all background tasks
    public func cancelAllBackgroundTasks() {
        backgroundTasks.removeAll()
    }
    
    // MARK: - Violation Handling
    
    private func reportViolation(_ violation: SandboxViolation) {
        logger?("[Sandbox] Violation for \(pluginId): \(violation)")
        onViolation?(violation)
    }
    
    // MARK: - Reset
    
    /// Reset sandbox state
    public func reset() {
        currentMemoryUsage = 0
        currentStorageUsage = 0
        activeNetworkRequests = 0
        cancelAllBackgroundTasks()
    }
}

/// Sandbox violation types
public enum SandboxViolation: Sendable {
    case memoryLimitExceeded(requested: UInt64, current: UInt64, limit: UInt64)
    case storageLimitExceeded(requested: UInt64, current: UInt64, limit: UInt64)
    case permissionDenied(Permission)
    case blockedHost(String)
    case hostNotAllowed(String)
    case tooManyConcurrentRequests(current: Int, limit: Int)
    case requestSizeExceeded(size: UInt64, limit: UInt64)
    case fileSystemAccessDenied(path: String)
    case tooManyBackgroundTasks
    case executionTimeout(taskId: String)
    
    public var description: String {
        switch self {
        case .memoryLimitExceeded(let requested, let current, let limit):
            return "Memory limit exceeded: requested \(requested), current \(current), limit \(limit)"
        case .storageLimitExceeded(let requested, let current, let limit):
            return "Storage limit exceeded: requested \(requested), current \(current), limit \(limit)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission.rawValue)"
        case .blockedHost(let host):
            return "Access to blocked host: \(host)"
        case .hostNotAllowed(let host):
            return "Host not in allowlist: \(host)"
        case .tooManyConcurrentRequests(let current, let limit):
            return "Too many concurrent requests: \(current)/\(limit)"
        case .requestSizeExceeded(let size, let limit):
            return "Request size exceeded: \(size)/\(limit)"
        case .fileSystemAccessDenied(let path):
            return "File system access denied: \(path)"
        case .tooManyBackgroundTasks:
            return "Too many concurrent background tasks"
        case .executionTimeout(let taskId):
            return "Task execution timeout: \(taskId)"
        }
    }
}
