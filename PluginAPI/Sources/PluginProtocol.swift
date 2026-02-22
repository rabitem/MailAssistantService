import Foundation

// Note: PluginStorage is defined in Models/PluginContext.swift with different signatures

// MARK: - Base Plugin Protocol

/// The base protocol that all plugins must conform to
public protocol Plugin: Sendable {
    /// Unique identifier for the plugin type
    static var pluginIdentifier: String { get }
    
    /// Human-readable name of the plugin
    static var displayName: String { get }
    
    /// Version of the plugin (semver format recommended)
    static var version: String { get }
    
    /// Description of what the plugin does
    static var description: String { get }
    
    /// The permissions this plugin requires
    static var requiredPermissions: [PluginPermission] { get }
    
    /// The type of plugin (for routing and UI purposes)
    static var pluginType: PluginType { get }
    
    /// Current context for the plugin
    var context: PluginContext { get }
    
    /// Initialize the plugin with a context
    init(context: PluginContext) async throws
    
    /// Called when the plugin is activated
    func activate() async throws
    
    /// Called when the plugin is deactivated
    func deactivate() async throws
    
    /// Update configuration dynamically
    func updateConfiguration(_ configuration: [String: AnyCodable]) async throws
}

// MARK: - Plugin Type

/// Enum representing the different types of plugins
public enum PluginType: String, Codable, Sendable, CaseIterable {
    case aiProvider = "ai_provider"
    case analysis = "analysis"
    case action = "action"
    case integration = "integration"
    case ui = "ui"
    case custom = "custom"
}

// MARK: - AnyCodable

/// A type-erased Codable value for flexible configuration
public struct AnyCodable: Codable, Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = ""
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Plugin State
// Note: PluginState is defined in Events/PluginEvent.swift with states: unloaded, loading, loaded, active, paused, error

// MARK: - Plugin Metadata

/// Metadata about a plugin for discovery and display
public struct PluginMetadata: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let version: String
    public let description: String
    public let type: PluginType
    public let requiredPermissions: [PluginPermission]
    public let author: String?
    public let homepageURL: String?
    public let iconURL: String?
    
    public init(
        id: String,
        displayName: String,
        version: String,
        description: String,
        type: PluginType,
        requiredPermissions: [PluginPermission] = [],
        author: String? = nil,
        homepageURL: String? = nil,
        iconURL: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.description = description
        self.type = type
        self.requiredPermissions = requiredPermissions
        self.author = author
        self.homepageURL = homepageURL
        self.iconURL = iconURL
    }
}
