import Foundation
import PluginAPI

/// Plugin manager errors
public enum PluginManagerError: Error, Sendable {
    case pluginNotFound(PluginID)
    case pluginAlreadyLoaded(PluginID)
    case dependencyNotMet(PluginDependency)
    case circularDependency([PluginID])
    case activationFailed(PluginID, Error)
    case deactivationFailed(PluginID, Error)
    case invalidState(PluginID, PluginState)
}

/// Plugin record for internal tracking
private struct PluginRecord: Sendable {
    let container: PluginContainer
    var state: PluginState
    var context: PluginContextImpl?
    var sandbox: PluginSandbox?
    var enabled: Bool
    var loadTime: Date?
    var lastError: Error?
}

/// Central plugin manager - the main entry point for plugin system
@MainActor
public final class PluginManager: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = PluginManager()
    
    // MARK: - Properties
    
    /// Loaded plugins
    private var plugins: [PluginID: PluginRecord] = [:]
    
    /// Plugin loader
    private var loader: PluginLoader!
    
    /// Permission manager
    private var permissionManager: PermissionManager!
    
    /// Event bus
    private var eventBus: EventBusImpl!
    
    /// Configuration
    private var configuration: PluginManagerConfiguration!
    
    /// Is the manager initialized
    private var isInitialized = false
    
    /// Background task for saving registry
    private var saveTask: Task<Void, Never>?
    
    /// Logger
    private var logger: ((String) -> Void) = { print($0) }
    
    // MARK: - Published Properties
    
    @Published public private(set) var loadedPlugins: [PluginID] = []
    @Published public private(set) var activePlugins: [PluginID] = []
    @Published public private(set) var pluginStates: [PluginID: PluginState] = [:]
    
    // MARK: - Initialization
    
    private init() {}
    
    /// Initialize the plugin manager
    public func initialize(with configuration: PluginManagerConfiguration) async throws {
        guard !isInitialized else {
            return
        }
        
        self.configuration = configuration
        
        // Initialize event bus
        eventBus = EventBusImpl(
            maxQueueSize: configuration.maxEventQueueSize,
            maxHistoryCount: configuration.maxEventHistory,
            logger: { [weak self] msg in self?.logger(msg) }
        )
        
        // Initialize permission manager
        let permissionsURL = configuration.storageDirectory
            .appendingPathComponent("permissions.json")
        permissionManager = PermissionManager(
            storageURL: permissionsURL,
            consentHandler: configuration.permissionConsentHandler,
            logger: { [weak self] msg in self?.logger(msg) }
        )
        try await permissionManager.loadPersistedPermissions()
        
        // Initialize plugin loader
        let externalPluginsDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("KimiMail/Plugins", isDirectory: true)
            ?? configuration.storageDirectory.appendingPathComponent("Plugins")
        
        loader = PluginLoader(
            externalPluginsDirectory: externalPluginsDir,
            builtInPluginsDirectory: configuration.builtInPluginsDirectory,
            appVersion: configuration.appVersion,
            logger: { [weak self] msg in self?.logger(msg) }
        )
        
        // Register built-in plugins
        for (id, factory) in configuration.builtInPlugins {
            await loader.registerBuiltInPlugin(id: id, factory: factory)
        }
        
        // Load registry
        try await loadRegistry()
        
        isInitialized = true
        logger("[PluginManager] Initialized")
        
        // Load and activate enabled plugins
        try await loadAndActivateEnabledPlugins()
    }
    
    // MARK: - Plugin Loading
    
    /// Load a plugin by ID
    @discardableResult
    public func loadPlugin(id: PluginID) async throws -> PluginContainer {
        ensureInitialized()
        
        // Check if already loaded
        if let record = plugins[id] {
            return record.container
        }
        
        // Load from loader
        let container = try await loader.loadPlugin(id: id)
        
        // Check dependencies
        try await resolveDependencies(for: container.manifest)
        
        // Create record
        var record = PluginRecord(
            container: container,
            state: .unloaded,
            context: nil,
            sandbox: nil,
            enabled: false,
            loadTime: nil,
            lastError: nil
        )
        
        // Setup sandbox
        let sandboxConfig = container.isBuiltIn 
            ? SandboxConfiguration.default 
            : SandboxConfiguration.restrictive
        
        let sandbox = PluginSandbox(
            pluginId: id,
            configuration: sandboxConfig,
            permissionProvider: PluginPermissionProvider(pluginId: id, manager: permissionManager),
            logger: { [weak self] msg in self?.logger(msg) },
            onViolation: { [weak self] violation in
                self?.handleSandboxViolation(pluginId: id, violation: violation)
            }
        )
        record.sandbox = sandbox
        
        // Store record
        plugins[id] = record
        updatePublishedState()
        
        // Emit event
        await eventBus.publish(PluginLoadedEvent(
            pluginId: id,
            manifest: container.manifest
        ))
        
        logger("[PluginManager] Loaded plugin: \(id)")
        
        return container
    }
    
    /// Load all available plugins
    public func loadAllPlugins() async -> [PluginID: Error] {
        ensureInitialized()
        
        let manifests = await loader.loadAvailableManifests()
        var errors: [PluginID: Error] = [:]
        
        for manifest in manifests {
            do {
                try await loadPlugin(id: manifest.id)
            } catch {
                errors[manifest.id] = error
            }
        }
        
        return errors
    }
    
    // MARK: - Plugin Activation
    
    /// Enable and activate a plugin
    public func enablePlugin(id: PluginID) async throws {
        ensureInitialized()
        
        // Load if not already loaded
        if plugins[id] == nil {
            try await loadPlugin(id: id)
        }
        
        guard var record = plugins[id] else {
            throw PluginManagerError.pluginNotFound(id)
        }
        
        record.enabled = true
        plugins[id] = record
        
        // Activate
        try await activatePlugin(id: id)
        
        // Save registry
        await saveRegistry()
        
        logger("[PluginManager] Enabled plugin: \(id)")
    }
    
    /// Disable a plugin
    public func disablePlugin(id: PluginID) async throws {
        ensureInitialized()
        
        guard var record = plugins[id] else {
            throw PluginManagerError.pluginNotFound(id)
        }
        
        // Deactivate first
        try await deactivatePlugin(id: id)
        
        record.enabled = false
        plugins[id] = record
        
        await saveRegistry()
        
        logger("[PluginManager] Disabled plugin: \(id)")
    }
    
    /// Activate a loaded plugin
    private func activatePlugin(id: PluginID) async throws {
        guard var record = plugins[id] else {
            throw PluginManagerError.pluginNotFound(id)
        }
        
        guard record.state != .active else { return }
        
        // Update state
        let oldState = record.state
        record.state = .loading
        record.loadTime = Date()
        plugins[id] = record
        updatePublishedState()
        
        await eventBus.publish(PluginStateChangedEvent(
            pluginId: id,
            oldState: oldState,
            newState: .loading
        ))
        
        do {
            // Create plugin context
            let storage = PluginStorageImpl(
                pluginId: id,
                baseDirectory: configuration.storageDirectory
            )
            
            let pluginLogger = PluginLoggerImpl(
                pluginId: id,
                logHandler: { [weak self] entry in
                    self?.handleLogEntry(entry)
                }
            )
            
            let context = PluginContextImpl(
                manifest: record.container.manifest,
                eventBus: eventBus,
                storage: storage,
                logger: pluginLogger,
                permissions: PluginPermissionProvider(pluginId: id, manager: permissionManager),
                aiService: nil, // Set up based on permissions
                emailService: nil, // Set up based on permissions
                networkService: nil, // Set up based on permissions
                settings: [:] // Load from settings store
            )
            
            record.context = context
            
            // Pre-grant permissions for built-in plugins
            if record.container.isBuiltIn {
                await permissionManager.pregrantPermissions(
                    record.container.manifest.permissions,
                    to: id
                )
            }
            
            // Activate plugin
            try await record.container.plugin.activate(context: context)
            
            // Update state
            record.state = .active
            plugins[id] = record
            updatePublishedState()
            
            await eventBus.publish(PluginStateChangedEvent(
                pluginId: id,
                oldState: .loading,
                newState: .active
            ))
            
            logger("[PluginManager] Activated plugin: \(id)")
            
        } catch {
            record.state = .error
            record.lastError = error
            plugins[id] = record
            updatePublishedState()
            
            await eventBus.publish(PluginStateChangedEvent(
                pluginId: id,
                oldState: .loading,
                newState: .error
            ))
            
            throw PluginManagerError.activationFailed(id, error)
        }
    }
    
    /// Deactivate a plugin
    private func deactivatePlugin(id: PluginID) async throws {
        guard var record = plugins[id] else {
            throw PluginManagerError.pluginNotFound(id)
        }
        
        guard record.state == .active else { return }
        
        let oldState = record.state
        record.state = .unloaded
        plugins[id] = record
        updatePublishedState()
        
        await eventBus.publish(PluginStateChangedEvent(
            pluginId: id,
            oldState: oldState,
            newState: .unloaded
        ))
        
        // Deactivate plugin
        await record.container.plugin.deactivate()
        
        // Reset sandbox
        if let sandbox = record.sandbox {
            await sandbox.reset()
        }
        
        await eventBus.publish(PluginUnloadedEvent(
            pluginId: id,
            reason: .userRequest
        ))
        
        logger("[PluginManager] Deactivated plugin: \(id)")
    }
    
    // MARK: - Plugin Unloading
    
    /// Unload a plugin completely
    public func unloadPlugin(id: PluginID) async throws {
        ensureInitialized()
        
        guard plugins[id] != nil else {
            throw PluginManagerError.pluginNotFound(id)
        }
        
        // Deactivate first
        try await deactivatePlugin(id: id)
        
        // Unload from loader
        await loader.unloadPlugin(id: id)
        
        // Remove record
        plugins.removeValue(forKey: id)
        updatePublishedState()
        
        logger("[PluginManager] Unloaded plugin: \(id)")
    }
    
    // MARK: - Dependency Resolution
    
    private func resolveDependencies(for manifest: PluginManifest) async throws {
        var resolved: [PluginID] = []
        var resolving: [PluginID] = []
        
        try await resolveDependenciesRecursive(
            for: manifest,
            resolved: &resolved,
            resolving: &resolving
        )
    }
    
    private func resolveDependenciesRecursive(
        for manifest: PluginManifest,
        resolved: inout [PluginID],
        resolving: inout [PluginID]
    ) async throws {
        // Check for circular dependency
        if resolving.contains(manifest.id) {
            throw PluginManagerError.circularDependency(resolving + [manifest.id])
        }
        
        // Already resolved
        if resolved.contains(manifest.id) {
            return
        }
        
        resolving.append(manifest.id)
        
        for dependency in manifest.dependencies where !dependency.optional {
            // Check if dependency is loaded
            if plugins[dependency.pluginId] == nil {
                // Try to load dependency
                do {
                    let depContainer = try await loader.loadPlugin(id: dependency.pluginId)
                    
                    // Recursively resolve dependency's dependencies
                    try await resolveDependenciesRecursive(
                        for: depContainer.manifest,
                        resolved: &resolved,
                        resolving: &resolving
                    )
                    
                    // Store loaded dependency
                    let record = PluginRecord(
                        container: depContainer,
                        state: .unloaded,
                        context: nil,
                        sandbox: nil,
                        enabled: false,
                        loadTime: nil,
                        lastError: nil
                    )
                    plugins[dependency.pluginId] = record
                    
                } catch {
                    throw PluginManagerError.dependencyNotMet(dependency)
                }
            }
        }
        
        resolving.removeAll { $0 == manifest.id }
        resolved.append(manifest.id)
    }
    
    // MARK: - Registry Persistence
    
    private func loadRegistry() async throws {
        let registryURL = configuration.storageDirectory
            .appendingPathComponent("registry.json")
        
        guard FileManager.default.fileExists(atPath: registryURL.path) else {
            return
        }
        
        let data = try Data(contentsOf: registryURL)
        let registry = try JSONDecoder().decode(PluginRegistry.self, from: data)
        
        // Load and activate enabled plugins from registry
        for entry in registry.entries {
            if entry.enabled {
                do {
                    // Load plugin if not already loaded
                    if plugins[entry.id] == nil {
                        let container = try await loader.loadPlugin(id: entry.id)
                        let record = PluginRecord(
                            container: container,
                            state: .unloaded,
                            context: nil,
                            sandbox: nil,
                            enabled: true,
                            loadTime: nil,
                            lastError: nil
                        )
                        plugins[entry.id] = record
                    }
                    
                    // Activate the plugin
                    try await activatePlugin(id: entry.id)
                    
                    // Update enabled state
                    if var record = plugins[entry.id] {
                        record.enabled = true
                        plugins[entry.id] = record
                    }
                    
                    logger("[PluginManager] Restored plugin from registry: \(entry.id)")
                } catch {
                    logger("[PluginManager] Failed to restore plugin \(entry.id): \(error)")
                }
            }
        }
    }
    
    private func saveRegistry() async {
        // Debounce saves
        saveTask?.cancel()
        
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            
            guard let self = self else { return }
            
            let entries = self.plugins.map { id, record in
                PluginRegistryEntry(
                    id: id,
                    enabled: record.enabled,
                    loadOrder: 0 // Calculate based on dependencies
                )
            }
            
            let registry = PluginRegistry(entries: entries)
            
            do {
                let data = try JSONEncoder().encode(registry)
                let registryURL = self.configuration.storageDirectory
                    .appendingPathComponent("registry.json")
                try data.write(to: registryURL, options: .atomic)
            } catch {
                self.logger("[PluginManager] Failed to save registry: \(error)")
            }
        }
    }
    
    private func loadAndActivateEnabledPlugins() async throws {
        // This would use the registry to determine which plugins to load
        // For now, load all available plugins
        let _ = await loadAllPlugins()
    }
    
    // MARK: - Public Accessors
    
    /// Get a loaded plugin
    public func getPlugin(id: PluginID) -> Plugin? {
        plugins[id]?.container.plugin
    }
    
    /// Get plugin state
    public func getPluginState(id: PluginID) -> PluginState? {
        plugins[id]?.state
    }
    
    /// Get plugin manifest
    public func getPluginManifest(id: PluginID) -> PluginManifest? {
        plugins[id]?.container.manifest
    }
    
    /// Get all loaded plugins
    public func getAllPlugins() -> [PluginContainer] {
        plugins.values.map { $0.container }
    }
    
    /// Get plugins by category
    public func getPlugins(category: PluginCategory) -> [PluginContainer] {
        plugins.values
            .filter { $0.container.manifest.category == category }
            .map { $0.container }
    }
    
    /// Get event bus
    public var events: EventBus {
        get async {
            await eventBus
        }
    }
    
    /// Get permission manager
    public var permissions: PermissionManager {
        permissionManager
    }
    
    // MARK: - Private Helpers
    
    private func ensureInitialized() {
        guard isInitialized else {
            fatalError("PluginManager not initialized. Call initialize() first.")
        }
    }
    
    private func updatePublishedState() {
        loadedPlugins = Array(plugins.keys)
        activePlugins = plugins
            .filter { $0.value.state == .active }
            .map { $0.key }
        pluginStates = plugins.mapValues { $0.state }
    }
    
    private func handleSandboxViolation(pluginId: PluginID, violation: SandboxViolation) {
        logger("[PluginManager] Sandbox violation by \(pluginId): \(violation)")
        
        // Handle based on severity
        switch violation {
        case .permissionDenied, .blockedHost, .hostNotAllowed:
            // Log and continue
            break
        case .memoryLimitExceeded, .storageLimitExceeded, .tooManyConcurrentRequests,
             .requestSizeExceeded, .tooManyBackgroundTasks:
            // Warn user
            break
        case .fileSystemAccessDenied, .executionTimeout:
            // Consider disabling plugin
            Task {
                try? await disablePlugin(id: pluginId)
            }
        }
    }
    
    private func handleLogEntry(_ entry: LogEntry) {
        let prefix = "[\(entry.pluginId)] [\(entry.level.rawValue.uppercased())]"
        logger("\(prefix) \(entry.message)")
    }
}

// MARK: - Configuration

public struct PluginManagerConfiguration: Sendable {
    public let storageDirectory: URL
    public let builtInPluginsDirectory: URL?
    public let builtInPlugins: [PluginID: () async throws -> Plugin]
    public let permissionConsentHandler: (PermissionRequest) async -> Bool
    public let appVersion: String
    public let maxEventQueueSize: Int
    public let maxEventHistory: Int
    
    public init(
        storageDirectory: URL,
        builtInPluginsDirectory: URL? = nil,
        builtInPlugins: [PluginID: () async throws -> Plugin] = [:],
        permissionConsentHandler: @escaping (PermissionRequest) async -> Bool,
        appVersion: String = "1.0.0",
        maxEventQueueSize: Int = 1000,
        maxEventHistory: Int = 100
    ) {
        self.storageDirectory = storageDirectory
        self.builtInPluginsDirectory = builtInPluginsDirectory
        self.builtInPlugins = builtInPlugins
        self.permissionConsentHandler = permissionConsentHandler
        self.appVersion = appVersion
        self.maxEventQueueSize = maxEventQueueSize
        self.maxEventHistory = maxEventHistory
    }
}

// MARK: - Registry Models

private struct PluginRegistry: Codable {
    let entries: [PluginRegistryEntry]
}

private struct PluginRegistryEntry: Codable {
    let id: PluginID
    let enabled: Bool
    let loadOrder: Int
}
