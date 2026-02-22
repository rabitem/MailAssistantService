import Foundation
import GRDB
import OSLog

/// Main database manager for the Mail Assistant service
/// Handles database setup, connection pooling, migrations, and provides access to all record types
public final class DatabaseManager: Sendable {
    private let logger = Logger(subsystem: "com.kimimail.assistant", category: "Database.Manager")
    
    /// Shared instance for app-wide database access
    public static let shared = DatabaseManager()
    
    /// The database queue for all database operations
    public let dbQueue: DatabaseQueue
    
    /// Migration runner instance
    public let migrationRunner: MigrationRunner
    
    /// Vector store for semantic search
    public private(set) var vectorStore: VectorStore?
    
    /// Database configuration
    private let config: DatabaseConfiguration
    
    /// Database path
    public let databasePath: String
    
    // MARK: - Initialization
    
    /// Database configuration options
    public struct DatabaseConfiguration: Sendable {
        /// Path to the database file
        public let path: String?
        
        /// Whether to use WAL mode (Write-Ahead Logging)
        public let walMode: Bool
        
        /// Maximum number of concurrent readers (WAL mode)
        public let maxReaders: Int
        
        /// Busy timeout in seconds
        public let busyTimeout: TimeInterval
        
        /// Whether to enable foreign keys
        public let foreignKeysEnabled: Bool
        
        /// Whether to run migrations on init
        public let autoMigrate: Bool
        
        /// Vector store configuration
        public let vectorConfig: VectorStore.Configuration
        
        public init(
            path: String? = nil,
            walMode: Bool = true,
            maxReaders: Int = 4,
            busyTimeout: TimeInterval = 30,
            foreignKeysEnabled: Bool = true,
            autoMigrate: Bool = true,
            vectorConfig: VectorStore.Configuration = .openAI
        ) {
            self.path = path
            self.walMode = walMode
            self.maxReaders = maxReaders
            self.busyTimeout = busyTimeout
            self.foreignKeysEnabled = foreignKeysEnabled
            self.autoMigrate = autoMigrate
            self.vectorConfig = vectorConfig
        }
        
        /// Default configuration with app container path
        public static let `default` = DatabaseConfiguration()
        
        /// Configuration for unit tests (in-memory database)
        public static let testing = DatabaseConfiguration(
            path: ":memory:",
            walMode: false,
            autoMigrate: true
        )
    }
    
    /// Initialize with custom configuration
    public init(config: DatabaseConfiguration = .default) throws {
        self.config = config
        
        // Determine database path
        if let path = config.path {
            self.databasePath = path
        } else {
            self.databasePath = DatabaseManager.defaultDatabasePath()
        }
        
        // Create directory if needed
        if self.databasePath != ":memory:" {
            let dbURL = URL(fileURLWithPath: self.databasePath)
            try FileManager.default.createDirectory(
                at: dbURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        // Configure GRDB
        var grdbConfig = Configuration()
        grdbConfig.readonly = false
        grdbConfig.foreignKeysEnabled = config.foreignKeysEnabled
        grdbConfig.busyMode = .timeout(config.busyTimeout)
        
        // Setup WAL mode if enabled
        if config.walMode && self.databasePath != ":memory:" {
            grdbConfig.prepareDatabase { db in
                try db.execute(sql: "PRAGMA journal_mode = WAL")
                try db.execute(sql: "PRAGMA synchronous = NORMAL")
                try db.execute(sql: "PRAGMA temp_store = MEMORY")
                try db.execute(sql: "PRAGMA mmap_size = 268435456") // 256MB
            }
        }
        
        // Create database queue
        self.dbQueue = try DatabaseQueue(path: self.databasePath, configuration: grdbConfig)
        
        // Initialize migration runner
        self.migrationRunner = MigrationRunner()
        
        // Run migrations if auto-migrate is enabled
        if config.autoMigrate {
            try runMigrations()
        }
        
        // Initialize vector store
        do {
            self.vectorStore = try VectorStore(dbQueue: dbQueue, config: config.vectorConfig)
            logger.info("Vector store initialized successfully")
        } catch {
            logger.warning("Failed to initialize vector store: \(error.localizedDescription)")
            self.vectorStore = nil
        }
        
        logger.info("DatabaseManager initialized at: \(self.databasePath)")
    }
    
    /// Initialize shared instance (called automatically)
    private convenience init() {
        do {
            try self.init(config: .default)
        } catch {
            fatalError("Failed to initialize DatabaseManager: \(error)")
        }
    }
    
    // MARK: - Database Path
    
    /// Returns the default database path in the app container
    private static func defaultDatabasePath() -> String {
        let fileManager = FileManager.default
        
        // Use Application Support directory
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            // Fallback to documents directory
            guard let documentsURL = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
                return "MailAssistant.db"
            }
            return documentsURL.appendingPathComponent("MailAssistant.db").path
        }
        
        // Create subdirectory for the app
        let dbDirectory = appSupportURL.appendingPathComponent("MailAssistant", isDirectory: true)
        return dbDirectory.appendingPathComponent("database.db").path
    }
    
    // MARK: - Migrations
    
    /// Run pending database migrations
    public func runMigrations() throws {
        try runMigrations(on: dbQueue)
    }
    
    /// Run migrations on a specific database queue
    public func runMigrations(on dbQueue: DatabaseQueue) throws {
        try runInTransaction { db in
            try migrationRunner.runMigrations(db: db)
        }
    }
    
    /// Check if migrations are needed
    public func hasPendingMigrations() throws -> Bool {
        return try dbQueue.read { db in
            try migrationRunner.hasPendingMigrations(db: db)
        }
    }
    
    /// Get migration status
    public func getMigrationStatus() throws -> (applied: [MigrationInfo], pending: [MigrationInfo]) {
        return try dbQueue.read { db in
            try migrationRunner.getMigrationStatus(db: db)
        }
    }
    
    // MARK: - Transaction Helpers
    
    /// Execute a write operation within a transaction
    @discardableResult
    public func write<T>(_ operation: (Database) throws -> T) throws -> T {
        return try dbQueue.write(operation)
    }
    
    /// Execute a read operation
    @discardableResult
    public func read<T>(_ operation: (Database) throws -> T) throws -> T {
        return try dbQueue.read(operation)
    }
    
    /// Execute operations within a transaction with rollback on failure
    @discardableResult
    public func runInTransaction<T>(_ operation: (Database) throws -> T) throws -> T {
        return try dbQueue.write { db in
            try db.inTransaction {
                do {
                    let result = try operation(db)
                    return .commit(result)
                } catch {
                    return .rollback(error)
                }
            }
        }
    }
    
    // MARK: - Database Maintenance
    
    /// Vacuum the database to reclaim space
    public func vacuum() throws {
        try dbQueue.write { db in
            try db.execute(sql: "VACUUM")
        }
        logger.info("Database vacuum completed")
    }
    
    /// Analyze the database for query optimization
    public func analyze() throws {
        try dbQueue.write { db in
            try db.execute(sql: "ANALYZE")
        }
        logger.info("Database analyze completed")
    }
    
    /// Checkpoint WAL file (merge changes into main database)
    public func checkpoint() throws {
        guard config.walMode else { return }
        
        try dbQueue.write { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
        logger.info("WAL checkpoint completed")
    }
    
    /// Get database statistics
    public func getStatistics() throws -> DatabaseStatistics {
        return try dbQueue.read { db in
            let pageSize = try Int.fetchOne(db, sql: "PRAGMA page_size") ?? 4096
            let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0
            let freelistCount = try Int.fetchOne(db, sql: "PRAGMA freelist_count") ?? 0
            
            let walSize = (try? Int.fetchOne(db, sql: "SELECT page_count * page_size FROM pragma_wal_checkpoint()")) ?? 0
            
            let tableCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sqlite_master WHERE type='table'
                """) ?? 0
            
            let indexCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sqlite_master WHERE type='index'
                """) ?? 0
            
            return DatabaseStatistics(
                pageSize: pageSize,
                pageCount: pageCount,
                freelistCount: freelistCount,
                databaseSize: Int64(pageCount) * Int64(pageSize),
                walSize: Int64(walSize),
                tableCount: tableCount,
                indexCount: indexCount
            )
        }
    }
    
    /// Close the database connection
    public func close() {
        // GRDB handles cleanup automatically
        logger.info("Database connection closed")
    }
    
    // MARK: - Backup & Restore
    
    /// Create a backup of the database
    public func backup(to path: String) throws {
        let backupURL = URL(fileURLWithPath: path)
        
        // Create backup directory if needed
        try FileManager.default.createDirectory(
            at: backupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Use SQLite's backup API
        try dbQueue.write { db in
            try db.execute(sql: "VACUUM INTO ?", arguments: [path])
        }
        
        logger.info("Database backed up to: \(path)")
    }
    
    /// Restore database from backup
    public static func restore(from path: String, to destinationPath: String? = nil) throws {
        let destPath = destinationPath ?? defaultDatabasePath()
        
        // Verify backup exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw DatabaseError.backupNotFound(path: path)
        }
        
        // Remove existing database
        if FileManager.default.fileExists(atPath: destPath) {
            try FileManager.default.removeItem(atPath: destPath)
        }
        
        // Copy backup
        try FileManager.default.copyItem(atPath: path, toPath: destPath)
        
        Logger(subsystem: "com.kimimail.assistant", category: "Database.Manager")
            .info("Database restored from: \(path)")
    }
}

// MARK: - Database Statistics

/// Statistics about the database
public struct DatabaseStatistics: Codable, CustomStringConvertible {
    public let pageSize: Int
    public let pageCount: Int
    public let freelistCount: Int
    public let databaseSize: Int64
    public let walSize: Int64
    public let tableCount: Int
    public let indexCount: Int
    
    public var description: String {
        let sizeMB = Double(databaseSize) / 1_048_576.0
        let walMB = Double(walSize) / 1_048_576.0
        
        return """
        Database Statistics:
        - Page Size: \(pageSize) bytes
        - Page Count: \(pageCount)
        - Freelist Pages: \(freelistCount)
        - Database Size: \(String(format: "%.2f", sizeMB)) MB
        - WAL Size: \(String(format: "%.2f", walMB)) MB
        - Tables: \(tableCount)
        - Indexes: \(indexCount)
        """
    }
    
    /// Returns true if database needs vacuuming
    public var needsVacuum: Bool {
        let fragmentation = Double(freelistCount) / Double(pageCount)
        return fragmentation > 0.2 // 20% fragmentation threshold
    }
}

// MARK: - Database Errors

public enum DatabaseError: LocalizedError {
    case backupNotFound(path: String)
    case migrationRequired
    case connectionFailed
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .backupNotFound(let path):
            return "Backup not found at: \(path)"
        case .migrationRequired:
            return "Database migration required"
        case .connectionFailed:
            return "Failed to connect to database"
        case .invalidConfiguration:
            return "Invalid database configuration"
        }
    }
}

// MARK: - Async Extensions

extension DatabaseManager {
    /// Async version of write operation
    public func writeAsync<T>(_ operation: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await dbQueue.write(operation)
    }
    
    /// Async version of read operation
    public func readAsync<T>(_ operation: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await dbQueue.read(operation)
    }
    
    /// Async transaction
    public func runInTransactionAsync<T>(_ operation: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await dbQueue.write { db in
            try db.inTransaction {
                do {
                    let result = try operation(db)
                    return .commit(result)
                } catch {
                    return .rollback(error)
                }
            }
        }
    }
}

// MARK: - Observability

extension DatabaseManager {
    /// Create a value observer for reactive updates
    public func observe<T: DatabaseValueConvertible & Equatable>(
        sql: String,
        arguments: StatementArguments = []
    ) -> ValueObservation<ValueReducers.Fetch<T?>> {
        return ValueObservation.tracking { db in
            try T.fetchOne(db, sql: sql, arguments: arguments)
        }
    }
    
    /// Create an observation for a record type
    public func observeAll<T: FetchableRecord & TableRecord>(
        _ type: T.Type,
        request: QueryInterfaceRequest<T>
    ) -> ValueObservation<ValueReducers.Fetch<[T]>> {
        return ValueObservation.tracking { db in
            try request.fetchAll(db)
        }
    }
}
