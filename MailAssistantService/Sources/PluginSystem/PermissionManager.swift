import Foundation
import PluginAPI

/// Permission manager implementation
public actor PermissionManager: PermissionProvider {
    /// Permission grant record
    private struct PermissionGrant: Codable {
        let pluginId: PluginID
        let permission: PluginPermission
        let granted: Bool
        let grantedAt: Date?
        let expiresAt: Date?
        let grantedByUser: Bool
    }
    
    /// In-memory permission store: [PluginID: Set<PluginPermission>]
    private var grantedPermissions: [PluginID: Set<PluginPermission>] = [:]
    
    /// Persistent storage URL
    private let storageURL: URL
    
    /// User consent handler
    private let consentHandler: (PermissionRequest) async -> Bool
    
    /// Permission change observers
    private var observers: [@Sendable (PluginID, PluginPermission, Bool) async -> Void] = []
    
    /// Logger
    private let logger: ((String) -> Void)?
    
    public init(
        storageURL: URL,
        consentHandler: @escaping (PermissionRequest) async -> Bool,
        logger: ((String) -> Void)? = nil
    ) {
        self.storageURL = storageURL
        self.consentHandler = consentHandler
        self.logger = logger
    }
    
    // MARK: - Initialization
    
    /// Load persisted permissions
    public func loadPersistedPermissions() async throws {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        
        let data = try Data(contentsOf: storageURL)
        let grants = try JSONDecoder().decode([PermissionGrant].self, from: data)
        
        let now = Date()
        for grant in grants {
            // Skip expired permissions
            if let expiresAt = grant.expiresAt, expiresAt < now {
                continue
            }
            
            if grant.granted {
                grantedPermissions[grant.pluginId, default: []].insert(grant.permission)
            }
        }
        
        logger?("[PermissionManager] Loaded permissions for \(grantedPermissions.count) plugins")
    }
    
    /// Save permissions to disk
    public func savePermissions() async throws {
        var grants: [PermissionGrant] = []
        let now = Date()
        
        for (pluginId, permissions) in grantedPermissions {
            for permission in permissions {
                grants.append(PermissionGrant(
                    pluginId: pluginId,
                    permission: permission,
                    granted: true,
                    grantedAt: now,
                    expiresAt: nil,
                    grantedByUser: true
                ))
            }
        }
        
        let data = try JSONEncoder().encode(grants)
        try data.write(to: storageURL, options: .atomic)
    }
    
    // MARK: - PermissionProvider Protocol
    
    public func hasPermission(_ permission: PluginPermission) async -> Bool {
        // This method requires plugin context, called from PluginContextImpl
        // The plugin context should pass its ID
        logger?("[PermissionManager] Error: hasPermission(_:) called without plugin context. Use hasPermission(_:for:) instead.")
        return false
    }
    
    public func requestPermission(_ permission: PluginPermission) async -> Bool {
        // This method requires plugin context, called from PluginContextImpl
        logger?("[PermissionManager] Error: requestPermission(_:) called without plugin context. Use requestPermission(_:for:) instead.")
        return false
    }
    
    public var grantedPermissions: [PluginPermission] {
        get async {
            // This method requires plugin context
            logger?("[PermissionManager] Error: grantedPermissions called without plugin context. Use grantedPermissions(for:) instead.")
            return []
        }
    }
    
    // MARK: - Permission Management API
    
    /// Check if a plugin has a specific permission
    public func hasPermission(_ permission: PluginPermission, for pluginId: PluginID) -> Bool {
        grantedPermissions[pluginId]?.contains(permission) ?? false
    }
    
    /// Check if a plugin has all the specified permissions
    public func hasPermissions(_ permissions: [PluginPermission], for pluginId: PluginID) -> Bool {
        let pluginPerms = grantedPermissions[pluginId] ?? []
        return permissions.allSatisfy { pluginPerms.contains($0) }
    }
    
    /// Get all granted permissions for a plugin
    public func grantedPermissions(for pluginId: PluginID) -> [PluginPermission] {
        Array(grantedPermissions[pluginId] ?? [])
    }
    
    /// Request a permission for a plugin
    public func requestPermission(_ permission: PluginPermission, for pluginId: PluginID) async -> Bool {
        // Check if already granted
        if hasPermission(permission, for: pluginId) {
            return true
        }
        
        // Build permission request
        let request = PermissionRequest(
            pluginId: pluginId,
            permission: permission,
            description: permission.description,
            riskLevel: permission.riskLevel,
            requiresConsent: permission.requiresUserConsent
        )
        
        // Get user consent if required
        let granted = await consentHandler(request)
        
        if granted {
            await grantPermission(permission, to: pluginId)
        }
        
        return granted
    }
    
    /// Request multiple permissions at once
    public func requestPermissions(_ permissions: [PluginPermission], for pluginId: PluginID) async -> [PluginPermission: Bool] {
        var results: [PluginPermission: Bool] = [:]
        
        for permission in permissions {
            results[permission] = await requestPermission(permission, for: pluginId)
        }
        
        return results
    }
    
    /// Grant a permission to a plugin (internal use)
    public func grantPermission(_ permission: PluginPermission, to pluginId: PluginID) {
        grantedPermissions[pluginId, default: []].insert(permission)
        
        Task {
            try? await savePermissions()
            await notifyObservers(pluginId: pluginId, permission: permission, granted: true)
            await publishPermissionChangedEvent(pluginId: pluginId, permission: permission, granted: true)
        }
        
        logger?("[PermissionManager] Granted \(permission.rawValue) to \(pluginId)")
    }
    
    /// Revoke a permission from a plugin
    public func revokePermission(_ permission: PluginPermission, from pluginId: PluginID) {
        grantedPermissions[pluginId]?.remove(permission)
        
        Task {
            try? await savePermissions()
            await notifyObservers(pluginId: pluginId, permission: permission, granted: false)
            await publishPermissionChangedEvent(pluginId: pluginId, permission: permission, granted: false)
        }
        
        logger?("[PermissionManager] Revoked \(permission.rawValue) from \(pluginId)")
    }
    
    /// Revoke all permissions from a plugin
    public func revokeAllPermissions(from pluginId: PluginID) {
        let permissions = grantedPermissions.removeValue(forKey: pluginId) ?? []
        
        Task {
            try? await savePermissions()
            for permission in permissions {
                await notifyObservers(pluginId: pluginId, permission: permission, granted: false)
                await publishPermissionChangedEvent(pluginId: pluginId, permission: permission, granted: false)
            }
        }
        
        logger?("[PermissionManager] Revoked all permissions from \(pluginId)")
    }
    
    /// Pre-grant permissions to a plugin (for built-in plugins)
    public func pregrantPermissions(_ permissions: [PluginPermission], to pluginId: PluginID) {
        for permission in permissions {
            grantedPermissions[pluginId, default: []].insert(permission)
        }
        
        Task {
            try? await savePermissions()
        }
        
        logger?("[PermissionManager] Pre-granted \(permissions.count) permissions to \(pluginId)")
    }
    
    // MARK: - Observers
    
    /// Add a permission change observer
    public func addObserver(_ observer: @Sendable @escaping (PluginID, PluginPermission, Bool) async -> Void) {
        observers.append(observer)
    }
    
    private func notifyObservers(pluginId: PluginID, permission: PluginPermission, granted: Bool) async {
        for observer in observers {
            await observer(pluginId, permission, granted)
        }
    }
    
    // MARK: - Event Publishing
    
    private func publishPermissionChangedEvent(pluginId: PluginID, permission: PluginPermission, granted: Bool) async {
        // This would be called through the event bus, but we need to avoid circular dependency
        // The actual event publishing should be handled by PluginManager
    }
}

/// Permission request model
public struct PermissionRequest: Sendable {
    public let pluginId: PluginID
    public let permission: PluginPermission
    public let description: String
    public let riskLevel: PermissionRiskLevel
    public let requiresConsent: Bool
}

/// Permission provider wrapper for plugin context
public struct PermissionProviderImpl: PermissionProvider {
    private let pluginId: PluginID
    private let manager: PermissionManager
    
    public init(pluginId: PluginID, manager: PermissionManager) {
        self.pluginId = pluginId
        self.manager = manager
    }
    
    public func hasPermission(_ permission: PluginPermission) async -> Bool {
        await manager.hasPermission(permission, for: pluginId)
    }
    
    public func requestPermission(_ permission: PluginPermission) async -> Bool {
        await manager.requestPermission(permission, for: pluginId)
    }
    
    public var grantedPermissions: [PluginPermission] {
        get async {
            await manager.grantedPermissions(for: pluginId)
        }
    }
}
