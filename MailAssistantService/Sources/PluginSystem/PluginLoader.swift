import Foundation
import PluginAPI

/// Plugin loading errors
public enum PluginLoaderError: Error, Sendable {
    case manifestNotFound
    case manifestInvalid(Error)
    case bundleNotFound
    case bundleInvalid
    case entryPointNotFound
    case classNotFound(String)
    case instantiationFailed(Error)
    case versionIncompatible(required: String, available: String)
    case dependencyResolutionFailed([PluginDependency])
    case invalidPluginType
    case permissionDenied
}

/// Plugin loader responsible for loading and instantiating plugins
public actor PluginLoader {
    /// Typealias for plugin factory
    public typealias PluginFactory = () async throws -> Plugin
    
    /// Registered built-in plugins
    private var builtInPlugins: [PluginID: PluginFactory] = [:]
    
    /// Plugin bundle cache
    private var bundleCache: [PluginID: Bundle] = [:]
    
    /// External plugins directory
    private let externalPluginsDirectory: URL
    
    /// Built-in plugins directory
    private let builtInPluginsDirectory: URL?
    
    /// Logger
    private let logger: ((String) -> Void)?
    
    /// Current app version for compatibility checks
    private let appVersion: String
    
    public init(
        externalPluginsDirectory: URL,
        builtInPluginsDirectory: URL? = nil,
        appVersion: String = "1.0.0",
        logger: ((String) -> Void)? = nil
    ) {
        self.externalPluginsDirectory = externalPluginsDirectory
        self.builtInPluginsDirectory = builtInPluginsDirectory
        self.appVersion = appVersion
        self.logger = logger
        
        // Ensure external plugins directory exists
        try? FileManager.default.createDirectory(
            at: externalPluginsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - Built-in Plugin Registration
    
    /// Register a built-in plugin
    public func registerBuiltInPlugin(id: PluginID, factory: @escaping PluginFactory) {
        builtInPlugins[id] = factory
        logger?("[PluginLoader] Registered built-in plugin: \(id)")
    }
    
    /// Check if a plugin is built-in
    public func isBuiltInPlugin(id: PluginID) -> Bool {
        builtInPlugins[id] != nil
    }
    
    // MARK: - Manifest Loading
    
    /// Load manifest from a bundle
    public func loadManifest(from bundleURL: URL) async throws -> PluginManifest {
        let manifestURL = bundleURL.appendingPathComponent("plugin.json")
        
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PluginLoaderError.manifestNotFound
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw PluginLoaderError.manifestInvalid(error)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let manifest = try decoder.decode(PluginManifest.self, from: data)
            
            // Validate version compatibility
            if let minVersion = manifest.minAppVersion {
                guard isVersionCompatible(appVersion: appVersion, requiredVersion: minVersion) else {
                    throw PluginLoaderError.versionIncompatible(
                        required: minVersion,
                        available: appVersion
                    )
                }
            }
            
            return manifest
        } catch let error as PluginLoaderError {
            throw error
        } catch {
            throw PluginLoaderError.manifestInvalid(error)
        }
    }
    
    /// Load manifest from a data object (for testing)
    public func loadManifest(from data: Data) async throws -> PluginManifest {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PluginManifest.self, from: data)
    }
    
    // MARK: - Plugin Loading
    
    /// Load a plugin by ID
    public func loadPlugin(id: PluginID) async throws -> PluginContainer {
        // Check if it's a built-in plugin
        if let factory = builtInPlugins[id] {
            let plugin = try await factory()
            return PluginContainer(
                id: id,
                manifest: plugin.manifest,
                plugin: plugin,
                isBuiltIn: true,
                bundleURL: nil
            )
        }
        
        // Try to load from external plugins
        let pluginURL = externalPluginsDirectory.appendingPathComponent("\(id.rawValue).plugin")
        
        guard FileManager.default.fileExists(atPath: pluginURL.path) else {
            throw PluginLoaderError.bundleNotFound
        }
        
        return try await loadPlugin(from: pluginURL, isBuiltIn: false)
    }
    
    /// Load a plugin from a specific bundle URL
    public func loadPlugin(from bundleURL: URL, isBuiltIn: Bool = false) async throws -> PluginContainer {
        // Load manifest
        let manifest = try await loadManifest(from: bundleURL)
        
        // For built-in plugins loaded from bundles
        if isBuiltIn, let factory = builtInPlugins[manifest.id] {
            let plugin = try await factory()
            return PluginContainer(
                id: manifest.id,
                manifest: manifest,
                plugin: plugin,
                isBuiltIn: true,
                bundleURL: bundleURL
            )
        }
        
        // Load external plugin bundle
        guard let bundle = Bundle(url: bundleURL) else {
            throw PluginLoaderError.bundleInvalid
        }
        
        bundleCache[manifest.id] = bundle
        
        // Load the principal class
        let plugin = try await instantiatePlugin(from: bundle, manifest: manifest)
        
        return PluginContainer(
            id: manifest.id,
            manifest: manifest,
            plugin: plugin,
            isBuiltIn: false,
            bundleURL: bundleURL
        )
    }
    
    /// Load all available plugins
    public func loadAllAvailablePlugins() async -> [PluginContainer] {
        var containers: [PluginContainer] = []
        
        // Load built-in plugins
        for (id, factory) in builtInPlugins {
            do {
                let plugin = try await factory()
                let container = PluginContainer(
                    id: id,
                    manifest: plugin.manifest,
                    plugin: plugin,
                    isBuiltIn: true,
                    bundleURL: nil
                )
                containers.append(container)
            } catch {
                logger?("[PluginLoader] Failed to load built-in plugin \(id): \(error)")
            }
        }
        
        // Load external plugins
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: externalPluginsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return containers
        }
        
        for url in contents where url.pathExtension == "plugin" {
            do {
                let container = try await loadPlugin(from: url, isBuiltIn: false)
                containers.append(container)
            } catch {
                logger?("[PluginLoader] Failed to load plugin at \(url): \(error)")
            }
        }
        
        return containers
    }
    
    /// Load available manifests without instantiating plugins
    public func loadAvailableManifests() async -> [PluginManifest] {
        var manifests: [PluginManifest] = []
        
        // Get built-in plugin manifests
        for (id, _) in builtInPlugins {
            // Built-in plugins should have their manifest embedded or registered separately
            // For now, we'll skip as they need to be instantiated
        }
        
        // Get external plugin manifests
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: externalPluginsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return manifests
        }
        
        for url in contents where url.pathExtension == "plugin" {
            do {
                let manifest = try await loadManifest(from: url)
                manifests.append(manifest)
            } catch {
                logger?("[PluginLoader] Failed to load manifest at \(url): \(error)")
            }
        }
        
        return manifests
    }
    
    // MARK: - Private Methods
    
    private func instantiatePlugin(from bundle: Bundle, manifest: PluginManifest) async throws -> Plugin {
        // Get the principal class from the bundle
        guard let principalClass = bundle.principalClass else {
            throw PluginLoaderError.entryPointNotFound
        }
        
        // Ensure it conforms to Plugin protocol
        guard principalClass is Plugin.Type else {
            throw PluginLoaderError.invalidPluginType
        }
        
        // Instantiate
        let pluginType = principalClass as! Plugin.Type
        
        do {
            let plugin = try await pluginType.init()
            return plugin
        } catch {
            throw PluginLoaderError.instantiationFailed(error)
        }
    }
    
    private func isVersionCompatible(appVersion: String, requiredVersion: String) -> Bool {
        let appComponents = appVersion.split(separator: ".").compactMap { Int($0) }
        let requiredComponents = requiredVersion.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(appComponents.count, requiredComponents.count)
        
        for i in 0..<maxLength {
            let app = i < appComponents.count ? appComponents[i] : 0
            let required = i < requiredComponents.count ? requiredComponents[i] : 0
            
            if app > required {
                return true
            } else if app < required {
                return false
            }
        }
        
        return true // Equal versions
    }
    
    // MARK: - Unloading
    
    /// Unload a plugin bundle
    public func unloadPlugin(id: PluginID) {
        bundleCache.removeValue(forKey: id)
        logger?("[PluginLoader] Unloaded plugin: \(id)")
    }
    
    /// Unload all plugins
    public func unloadAll() {
        bundleCache.removeAll()
        logger?("[PluginLoader] Unloaded all plugins")
    }
}

/// Container for a loaded plugin
public struct PluginContainer: Sendable {
    public let id: PluginID
    public let manifest: PluginManifest
    public let plugin: Plugin
    public let isBuiltIn: Bool
    public let bundleURL: URL?
    
    public init(
        id: PluginID,
        manifest: PluginManifest,
        plugin: Plugin,
        isBuiltIn: Bool,
        bundleURL: URL?
    ) {
        self.id = id
        self.manifest = manifest
        self.plugin = plugin
        self.isBuiltIn = isBuiltIn
        self.bundleURL = bundleURL
    }
}
