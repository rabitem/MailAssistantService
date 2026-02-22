//
//  LifecycleManager.swift
//  MailAssistantService
//
//  Service startup/shutdown, plugin initialization, and database setup
//

import Foundation
import os.log

// MARK: - Lifecycle Manager

/// Manages the service lifecycle including startup, shutdown, and initialization
class LifecycleManager {
    
    // MARK: - Singleton
    
    static let shared = LifecycleManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.kimimail.assistant.service", category: "LifecycleManager")
    private let startupTime = Date()
    
    private var isInitialized = false
    private let initializationLock = NSLock()
    
    private var databaseManager: DatabaseManager?
    private var pluginManager: PluginManager?
    private var backgroundTaskManager: BackgroundTaskManager?
    
    /// Current service health status
    private(set) var healthStatus: ServiceHealth = .unknown
    
    /// Last email import timestamp
    private(set) var lastEmailImport: Date?
    
    // MARK: - Initialization
    
    private init() {
        logger.info("LifecycleManager created")
    }
    
    // MARK: - Service Lifecycle
    
    /// Initializes all service components
    func initialize() -> Bool {
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        guard !isInitialized else {
            logger.warning("Service already initialized")
            return true
        }
        
        logger.info("🚀 Starting service initialization...")
        
        do {
            // Step 1: Set up database
            try setupDatabase()
            
            // Step 2: Initialize plugin manager
            try setupPluginManager()
            
            // Step 3: Set up background tasks
            setupBackgroundTasks()
            
            // Step 4: Perform any migrations
            try performMigrations()
            
            isInitialized = true
            healthStatus = .healthy
            
            logger.info("✅ Service initialization complete")
            return true
            
        } catch {
            logger.error("❌ Service initialization failed: \(error.localizedDescription)")
            healthStatus = .unhealthy(reason: error.localizedDescription)
            return false
        }
    }
    
    /// Shuts down all service components gracefully
    func shutdown() {
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        logger.info("🛑 Shutting down service...")
        
        // Stop background tasks
        backgroundTaskManager?.stopAllTasks()
        
        // Unload plugins
        pluginManager?.unloadAllPlugins()
        
        // Close database connections
        databaseManager?.close()
        
        isInitialized = false
        healthStatus = .shuttingDown
        
        logger.info("✅ Service shutdown complete")
    }
    
    /// Called when there are no active connections
    func handleNoActiveConnections() {
        logger.info("No active connections - service may idle")
        
        // XPC services typically stay alive for a while even without connections
        // We can schedule a delayed shutdown here if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            // Check if still no connections after 5 minutes
            // If so, we could shut down, but typically XPC services let the system manage this
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupDatabase() throws {
        logger.info("📦 Setting up database...")
        
        databaseManager = DatabaseManager()
        try databaseManager?.initialize()
        
        logger.info("✅ Database setup complete")
    }
    
    private func setupPluginManager() throws {
        logger.info("🔌 Setting up plugin manager...")
        
        pluginManager = PluginManager.shared
        try pluginManager?.initialize()
        
        logger.info("✅ Plugin manager setup complete")
    }
    
    private func setupBackgroundTasks() {
        logger.info("⏰ Setting up background tasks...")
        
        backgroundTaskManager = BackgroundTaskManager.shared
        backgroundTaskManager?.startDefaultTasks()
        
        logger.info("✅ Background tasks setup complete")
    }
    
    private func performMigrations() throws {
        logger.info("🔄 Checking for migrations...")
        
        let migrationManager = MigrationManager()
        try migrationManager.runPendingMigrations()
        
        logger.info("✅ Migrations complete")
    }
    
    // MARK: - Health & Info
    
    /// Current service information
    var currentServiceInfo: ServiceInfo {
        let uptime = Date().timeIntervalSince(startupTime)
        let dbSize = databaseManager?.databaseSize ?? 0
        
        return ServiceInfo(
            version: ServiceConstants.version,
            buildNumber: ServiceConstants.buildNumber,
            startupTime: startupTime,
            uptime: uptime,
            activeConnections: 0, // Updated by ServiceDelegate
            databaseSize: dbSize,
            lastEmailImport: lastEmailImport,
            isHealthy: healthStatus.isHealthy
        )
    }
    
    /// Updates the last email import timestamp
    func updateLastEmailImport() {
        lastEmailImport = Date()
    }
    
    /// Performs a health check
    func performHealthCheck() -> ServiceHealth {
        // Check database connectivity
        let dbHealthy = databaseManager?.isConnected ?? false
        
        // Check plugin manager status
        let pluginsHealthy = pluginManager?.isHealthy ?? false
        
        if dbHealthy && pluginsHealthy {
            healthStatus = .healthy
        } else {
            var issues: [String] = []
            if !dbHealthy { issues.append("Database not connected") }
            if !pluginsHealthy { issues.append("Plugin manager unhealthy") }
            healthStatus = .unhealthy(reason: issues.joined(separator: ", "))
        }
        
        return healthStatus
    }
}

// MARK: - Service Health Enum

enum ServiceHealth {
    case unknown
    case healthy
    case unhealthy(reason: String)
    case shuttingDown
    
    var isHealthy: Bool {
        if case .healthy = self {
            return true
        }
        return false
    }
    
    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .healthy:
            return "Healthy"
        case .unhealthy(let reason):
            return "Unhealthy: \(reason)"
        case .shuttingDown:
            return "Shutting Down"
        }
    }
}

// MARK: - Service Constants

enum ServiceConstants {
    static let version = "1.0.0"
    static let buildNumber = "100"
    static let minimumSystemVersion = "14.0"
}

// MARK: - Placeholder Classes

/// Placeholder for database management
class DatabaseManager {
    private(set) var isConnected = false
    
    func initialize() throws {
        // TODO: Implement actual database initialization
        isConnected = true
    }
    
    func close() {
        isConnected = false
    }
    
    var databaseSize: UInt64 {
        // TODO: Calculate actual database size
        return 0
    }
}

/// Placeholder for migration management
class MigrationManager {
    func runPendingMigrations() throws {
        // TODO: Implement database migrations
    }
}

/// Placeholder for plugin manager
class PluginManager {
    static let shared = PluginManager()
    
    private(set) var isHealthy = false
    
    func initialize() throws {
        // TODO: Implement plugin manager initialization
        isHealthy = true
    }
    
    func unloadAllPlugins() {
        // TODO: Implement plugin unloading
    }
    
    func enablePlugin(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement plugin enable
        completion(.success(()))
    }
    
    func disablePlugin(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement plugin disable
        completion(.success(()))
    }
    
    func getAllPluginStatuses() -> [PluginStatus] {
        // TODO: Return actual plugin statuses
        return []
    }
    
    func getAvailablePlugins() -> [PluginInfo] {
        // TODO: Return available plugins
        return []
    }
}

/// Plugin information structure
struct PluginInfo: Codable {
    let id: String
    let name: String
    let version: String
    let description: String
    let author: String
    let isBuiltIn: Bool
}
