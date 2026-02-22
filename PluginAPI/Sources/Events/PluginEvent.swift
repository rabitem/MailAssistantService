import Foundation

/// Base protocol for all plugin events
public protocol PluginEvent: Sendable {
    /// Event type identifier
    static var eventType: String { get }
    
    /// Unique event ID
    var eventId: UUID { get }
    
    /// Timestamp when the event was created
    var timestamp: Date { get }
    
    /// Source plugin that emitted the event (nil for system events)
    var source: PluginID? { get }
}

/// Default implementations for PluginEvent
public extension PluginEvent {
    static var eventType: String {
        return String(describing: Self.self)
    }
}

/// Event wrapper for type-erased event handling
public struct AnyPluginEvent: Sendable {
    public let eventType: String
    public let eventId: UUID
    public let timestamp: Date
    public let source: PluginID?
    public let payload: any Sendable
    
    public init<E: PluginEvent>(_ event: E, payload: any Sendable) {
        self.eventType = E.eventType
        self.eventId = event.eventId
        self.timestamp = event.timestamp
        self.source = event.source
        self.payload = payload
    }
}

// MARK: - System Events

/// Event emitted when a plugin is loaded
public struct PluginLoadedEvent: PluginEvent {
    public let eventId = UUID()
    public let timestamp = Date()
    public let source: PluginID? = nil
    public let pluginId: PluginID
    public let manifest: PluginManifest
}

/// Event emitted when a plugin is unloaded
public struct PluginUnloadedEvent: PluginEvent {
    public let eventId = UUID()
    public let timestamp = Date()
    public let source: PluginID? = nil
    public let pluginId: PluginID
    public let reason: UnloadReason
    
    public enum UnloadReason: String, Sendable {
        case userRequest
        case error
        case dependencyMissing
        case update
        case systemShutdown
    }
}

/// Event emitted when a plugin state changes
public struct PluginStateChangedEvent: PluginEvent {
    public let eventId = UUID()
    public let timestamp = Date()
    public let source: PluginID? = nil
    public let pluginId: PluginID
    public let oldState: PluginState
    public let newState: PluginState
}

public enum PluginState: String, Sendable {
    case unloaded
    case loading
    case loaded
    case active
    case paused
    case error
}

/// Event emitted when a permission is granted or revoked
public struct PermissionChangedEvent: PluginEvent {
    public let eventId = UUID()
    public let timestamp = Date()
    public let source: PluginID? = nil
    public let pluginId: PluginID
    public let permission: Permission
    public let granted: Bool
}

/// Event emitted when new email arrives
public struct NewEmailEvent: PluginEvent {
    public let eventId = UUID()
    public let timestamp = Date()
    public let source: PluginID? = nil
    public let emailId: String
    public let accountId: String
    public let subject: String
    public let sender: String
    public let receivedDate: Date
}

/// Event for background task execution
public struct BackgroundTaskEvent: PluginEvent {
    public let eventId = UUID()
    public let timestamp = Date()
    public let source: PluginID?
    public let taskId: String
    public let taskType: String
    public let data: [String: String]?
}
