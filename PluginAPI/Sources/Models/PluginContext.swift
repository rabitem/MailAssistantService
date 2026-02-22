import Foundation

/// Context passed to plugins during initialization and operation
public protocol PluginContext: Sendable {
    /// The plugin's manifest
    var manifest: PluginManifest { get }
    
    /// Event bus for publishing and subscribing to events
    var eventBus: EventBus { get }
    
    /// Storage service for plugin data
    var storage: PluginStorage { get }
    
    /// Logger for plugin
    var logger: PluginLogger { get }
    
    /// Permission manager
    var permissions: PermissionProvider { get }
    
    /// AI service provider (if AI permission granted)
    var aiService: AIServiceProvider? { get }
    
    /// Email service (if email permissions granted)
    var emailService: EmailServiceProvider? { get }
    
    /// Network service (if network permission granted)
    var networkService: NetworkServiceProvider? { get }
    
    /// Current plugin settings
    var settings: [String: Any] { get }
}

/// Event bus protocol for pub/sub
public protocol EventBus: Sendable {
    /// Subscribe to events of a specific type
    /// - Parameters:
    ///   - eventType: The event type to subscribe to
    ///   - handler: Closure to handle events
    /// - Returns: Subscription identifier
    func subscribe<E: PluginEvent>(
        to eventType: E.Type,
        handler: @escaping @Sendable (E) async -> Void
    ) -> EventSubscription
    
    /// Subscribe to all events
    /// - Parameter handler: Closure to handle all events
    /// - Returns: Subscription identifier
    func subscribeToAll(handler: @escaping @Sendable (AnyPluginEvent) async -> Void) -> EventSubscription
    
    /// Publish an event
    /// - Parameter event: The event to publish
    func publish<E: PluginEvent>(_ event: E) async
    
    /// Unsubscribe from events
    /// - Parameter subscription: The subscription to cancel
    func unsubscribe(_ subscription: EventSubscription)
}

/// Event subscription identifier
public struct EventSubscription: Hashable, Sendable {
    public let id: UUID
    
    public init(id: UUID = UUID()) {
        self.id = id
    }
}

/// Storage service for plugins
public protocol PluginStorage: Sendable {
    /// Store a value
    /// - Parameters:
    ///   - value: Value to store (must be Codable)
    ///   - key: Storage key
    func set<T: Codable & Sendable>(_ value: T, forKey key: String) async throws
    
    /// Retrieve a value
    /// - Parameter key: Storage key
    /// - Returns: Stored value or nil
    func get<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T?
    
    /// Remove a value
    /// - Parameter key: Storage key
    func remove(forKey key: String) async throws
    
    /// Get all keys
    var allKeys: [String] { get async }
    
    /// Clear all stored data
    func clear() async throws
}

/// Logger for plugins
public protocol PluginLogger: Sendable {
    /// Log debug message
    func debug(_ message: String, file: String, line: Int, function: String)
    
    /// Log info message
    func info(_ message: String, file: String, line: Int, function: String)
    
    /// Log warning message
    func warning(_ message: String, file: String, line: Int, function: String)
    
    /// Log error message
    func error(_ message: String, error: Error?, file: String, line: Int, function: String)
}

public extension PluginLogger {
    func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        debug(message, file: file, line: line, function: function)
    }
    
    func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        info(message, file: file, line: line, function: function)
    }
    
    func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        warning(message, file: file, line: line, function: function)
    }
    
    func error(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line, function: String = #function) {
        error(message, error: error, file: file, line: line, function: function)
    }
}

/// Permission provider
public protocol PermissionProvider: Sendable {
    /// Check if plugin has a permission
    /// - Parameter permission: The permission to check
    /// - Returns: True if granted
    func hasPermission(_ permission: Permission) async -> Bool
    
    /// Request a permission
    /// - Parameter permission: The permission to request
    /// - Returns: True if granted
    func requestPermission(_ permission: Permission) async -> Bool
    
    /// Get all granted permissions
    var grantedPermissions: [Permission] { get async }
}

/// AI service provider
public protocol AIServiceProvider: Sendable {
    /// Complete a prompt using the default AI provider
    func complete(prompt: String, options: AIOptions) async throws -> String
    
    /// Get available models
    func availableModels() async -> [String]
    
    /// Get embedding for text
    func embed(text: String) async throws -> [Float]
}

/// Email service provider
public protocol EmailServiceProvider: Sendable {
    /// Get emails from a mailbox
    func fetchEmails(from mailbox: String, limit: Int) async throws -> [EmailMessage]
    
    /// Get a single email by ID
    func getEmail(id: String) async throws -> EmailMessage?
    
    /// Apply an action to an email
    func applyAction(_ action: EmailAction, to emailId: String) async throws
    
    /// Send an email
    func sendEmail(_ email: EmailMessage) async throws
    
    /// Search emails
    func search(query: String) async throws -> [EmailMessage]
}

/// Network service provider
public protocol NetworkServiceProvider: Sendable {
    /// Make a network request
    /// - Parameter request: The request to make
    /// - Returns: Response data
    func request(_ request: NetworkRequest) async throws -> NetworkResponse
    
    /// Check if network is available
    var isAvailable: Bool { get async }
}

public struct NetworkRequest: Sendable {
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval
    
    public init(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public struct NetworkResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public let headers: [String: String]
    
    public init(data: Data, statusCode: Int, headers: [String: String]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}
