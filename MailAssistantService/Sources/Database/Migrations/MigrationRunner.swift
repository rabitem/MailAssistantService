import Foundation
import GRDB
import OSLog

/// Manages database migrations and schema versioning
public final class MigrationRunner {
    private let logger = Logger(subsystem: "com.kimimail.assistant", category: "Database.Migration")
    
    /// All available migrations in order
    private let migrations: [DatabaseMigration] = [
        InitialSchemaMigration()
        // Add new migrations here in order
        // Example: AddEmailCategoriesMigration()
        // Example: AddUserPreferencesMigration()
    ]
    
    /// Current schema version
    public var currentVersion: Int64 {
        migrations.map(\.version).max() ?? 0
    }
    
    /// Runs all pending migrations
    /// - Parameter dbQueue: The database queue to migrate
    public func runMigrations(on dbQueue: DatabaseQueue) async throws {
        try await dbQueue.write { db in
            try self.runMigrations(db: db)
        }
    }
    
    /// Runs all pending migrations (synchronous version)
    /// - Parameter db: The database connection
    public func runMigrations(db: Database) throws {
        // Create schema_migrations table if it doesn't exist
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)
        
        // Get applied migrations
        let appliedVersions = try Set<Int64>(
            Int64.fetchAll(db, sql: "SELECT version FROM schema_migrations")
        )
        
        // Run pending migrations in order
        for migration in migrations {
            if appliedVersions.contains(migration.version) {
                logger.debug("Migration \(migration.version) already applied: \(migration.name)")
                continue
            }
            
            logger.info("Applying migration \(migration.version): \(migration.name)")
            
            // Check if we're already inside a transaction to avoid nested transaction issues
            let alreadyInTransaction = db.isInsideTransaction
            
            if !alreadyInTransaction {
                try db.execute(sql: "BEGIN TRANSACTION")
            }
            
            do {
                try migration.migrate(db)
                try db.execute(sql: """
                    INSERT INTO schema_migrations (version, name, applied_at)
                    VALUES (?, ?, ?)
                    """, arguments: [
                        migration.version,
                        migration.name,
                        Date()
                    ])
                if !alreadyInTransaction {
                    try db.execute(sql: "COMMIT")
                }
                logger.info("Successfully applied migration \(migration.version)")
            } catch {
                if !alreadyInTransaction {
                    try? db.execute(sql: "ROLLBACK")
                }
                logger.error("Failed to apply migration \(migration.version): \(error.localizedDescription)")
                throw MigrationError.migrationFailed(version: migration.version, name: migration.name, underlying: error)
            }
        }
        
        logger.info("Database migrations complete. Schema version: \(currentVersion)")
    }
    
    /// Checks if migrations are needed
    /// - Parameter db: The database connection
    /// - Returns: True if there are pending migrations
    public func hasPendingMigrations(db: Database) throws -> Bool {
        let appliedVersions = try Set<Int64>(
            Int64.fetchAll(db, sql: "SELECT version FROM schema_migrations")
        )
        
        return migrations.contains { !appliedVersions.contains($0.version) }
    }
    
    /// Gets migration status
    /// - Parameter db: The database connection  
    /// - Returns: Tuple of (applied migrations, pending migrations)
    public func getMigrationStatus(db: Database) throws -> (applied: [MigrationInfo], pending: [MigrationInfo]) {
        let applied = try MigrationInfo.fetchAll(db, sql: "SELECT * FROM schema_migrations ORDER BY version")
        let appliedVersions = Set(applied.map(\.version))
        
        let pending = migrations
            .filter { !appliedVersions.contains($0.version) }
            .map { MigrationInfo(version: $0.version, name: $0.name, appliedAt: nil) }
        
        return (applied, pending)
    }
    
    /// Resets all migrations (dangerous - for testing only)
    /// - Parameter dbQueue: The database queue
    public func resetMigrations(on dbQueue: DatabaseQueue) async throws {
        logger.warning("Resetting all migrations!")
        
        try await dbQueue.write { db in
            // Drop all tables
            let tables = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master 
                WHERE type='table' AND name NOT LIKE 'sqlite_%'
                """)
            
            for table in tables {
                try db.execute(sql: "DROP TABLE IF EXISTS \(table)")
            }
            
            // Drop all indexes
            let indexes = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master 
                WHERE type='index' AND name NOT LIKE 'sqlite_%'
                """)
            
            for index in indexes {
                try db.execute(sql: "DROP INDEX IF EXISTS \(index)")
            }
            
            // Drop all triggers
            let triggers = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master 
                WHERE type='trigger'
                """)
            
            for trigger in triggers {
                try db.execute(sql: "DROP TRIGGER IF EXISTS \(trigger)")
            }
        }
        
        // Re-run migrations
        try await runMigrations(on: dbQueue)
    }
}

// MARK: - Migration Error

public enum MigrationError: LocalizedError {
    case migrationFailed(version: Int64, name: String, underlying: Error)
    case invalidMigrationOrder
    
    public var errorDescription: String? {
        switch self {
        case .migrationFailed(let version, let name, let underlying):
            return "Migration \(version) '\(name)' failed: \(underlying.localizedDescription)"
        case .invalidMigrationOrder:
            return "Migrations are not in sequential order"
        }
    }
}

// MARK: - Migration Info

public struct MigrationInfo: Codable, FetchableRecord {
    public let version: Int64
    public let name: String
    public let appliedAt: Date?
}
