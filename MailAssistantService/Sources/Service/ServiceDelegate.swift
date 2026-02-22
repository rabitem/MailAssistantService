//
//  ServiceDelegate.swift
//  MailAssistantService
//
//  NSXPCListenerDelegate implementation for handling incoming connections
//

import Foundation
import os.log

// MARK: - Service Delegate

/// Handles incoming XPC connections and manages service lifecycle
class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.kimimail.assistant.service", category: "ServiceDelegate")
    private let lifecycleManager = LifecycleManager.shared
n    private var activeConnections: Set<NSXPCConnection> = []
    private let connectionLock = NSLock()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        logger.info("ServiceDelegate initialized")
    }
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.info("🔌 New XPC connection request from: \(newConnection.processIdentifier)")
        
        // Configure the connection
        configureConnection(newConnection)
        
        // Track the connection
        connectionLock.lock()
        activeConnections.insert(newConnection)
        connectionLock.unlock()
        
        // Set up invalidation handler
        newConnection.invalidationHandler = { [weak self] in
            self?.handleConnectionInvalidation(newConnection)
        }
        
        // Resume the connection
        newConnection.resume()
        
        logger.info("✅ XPC connection accepted and resumed")
        return true
    }
    
    // MARK: - Connection Management
    
    private func configureConnection(_ connection: NSXPCConnection) {
        // Set the interface that the remote object will export
        connection.exportedInterface = NSXPCInterface(with: MailAssistantServiceProtocol.self)
        
        // Create the service implementation
        let service = XPCService()
        connection.exportedObject = service
        
        // Set the interface for remote objects we might call
        connection.remoteObjectInterface = NSXPCInterface(with: MailAssistantClientProtocol.self)
        
        logger.debug("Connection configured with service interface")
    }
    
    private func handleConnectionInvalidation(_ connection: NSXPCConnection) {
        connectionLock.lock()
        activeConnections.remove(connection)
        let count = activeConnections.count
        connectionLock.unlock()
        
        logger.info("🔌 XPC connection invalidated. Active connections: \(count)")
        
        // If no more connections, we could potentially shut down
        // but XPC services typically stay alive for a while
        if count == 0 {
            lifecycleManager.handleNoActiveConnections()
        }
    }
    
    // MARK: - Public Methods
    
    /// Returns the number of currently active connections
    var connectionCount: Int {
        connectionLock.lock()
        let count = activeConnections.count
        connectionLock.unlock()
        return count
    }
    
    /// Disconnects all active connections
    func disconnectAll() {
        connectionLock.lock()
        let connections = Array(activeConnections)
        activeConnections.removeAll()
        connectionLock.unlock()
        
        for connection in connections {
            connection.invalidate()
        }
        
        logger.info("Disconnected all XPC connections")
    }
}

// MARK: - Connection Audit Log

extension ServiceDelegate {
    
    /// Logs connection audit information for debugging
    func logConnectionAudit() {
        connectionLock.lock()
        let count = activeConnections.count
        let pids = activeConnections.map { $0.processIdentifier }
        connectionLock.unlock()
        
        logger.info("📊 Connection Audit: \(count) active connections")
        for pid in pids {
            logger.debug("  - Process ID: \(pid)")
        }
    }
}
