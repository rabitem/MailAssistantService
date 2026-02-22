import Foundation
import GRDB

/// Initial database schema migration
/// Creates all core tables for the Mail Assistant service
struct InitialSchemaMigration: DatabaseMigration {
    let version: Int64 = 1
    let name: String = "Initial Schema"
    
    func migrate(_ db: Database) throws {
        // MARK: - Plugins Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS plugins (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                version TEXT NOT NULL,
                bundle_id TEXT NOT NULL UNIQUE,
                author TEXT,
                description TEXT,
                permissions TEXT NOT NULL DEFAULT '[]',
                is_enabled BOOLEAN NOT NULL DEFAULT 1,
                is_system BOOLEAN NOT NULL DEFAULT 0,
                settings_schema TEXT,
                default_settings TEXT,
                installed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_plugins_enabled ON plugins(is_enabled)
            """)
        
        // MARK: - Plugin Data Table (Key-Value Storage)
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS plugin_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plugin_id TEXT NOT NULL,
                key TEXT NOT NULL,
                value TEXT,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (plugin_id) REFERENCES plugins(id) ON DELETE CASCADE,
                UNIQUE(plugin_id, key)
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_plugin_data_plugin ON plugin_data(plugin_id)
            """)
        
        // MARK: - Contacts Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS contacts (
                id TEXT PRIMARY KEY NOT NULL,
                email_address TEXT NOT NULL UNIQUE,
                display_name TEXT,
                first_name TEXT,
                last_name TEXT,
                company TEXT,
                title TEXT,
                phone TEXT,
                notes TEXT,
                relationship_score REAL DEFAULT 0.0,
                email_frequency INTEGER DEFAULT 0,
                last_contacted_at DATETIME,
                avatar_url TEXT,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email_address)
            """)
        
        // MARK: - Threads Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS threads (
                id TEXT PRIMARY KEY NOT NULL,
                subject TEXT,
                participants TEXT NOT NULL DEFAULT '[]',
                message_count INTEGER NOT NULL DEFAULT 0,
                last_message_at DATETIME,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_threads_last_message ON threads(last_message_at)
            """)
        
        // MARK: - Emails Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS emails (
                id TEXT PRIMARY KEY NOT NULL,
                message_id TEXT NOT NULL UNIQUE,
                thread_id TEXT,
                account_id TEXT NOT NULL,
                folder TEXT NOT NULL DEFAULT 'INBOX',
                subject TEXT,
                body_text TEXT,
                body_html TEXT,
                from_address TEXT NOT NULL,
                from_name TEXT,
                to_addresses TEXT NOT NULL DEFAULT '[]',
                cc_addresses TEXT DEFAULT '[]',
                bcc_addresses TEXT DEFAULT '[]',
                sender_contact_id TEXT,
                sent_at DATETIME,
                received_at DATETIME NOT NULL,
                is_read BOOLEAN NOT NULL DEFAULT 0,
                is_flagged BOOLEAN NOT NULL DEFAULT 0,
                is_archived BOOLEAN NOT NULL DEFAULT 0,
                is_draft BOOLEAN NOT NULL DEFAULT 0,
                priority INTEGER DEFAULT 0,
                summary TEXT,
                action_items TEXT DEFAULT '[]',
                category TEXT,
                sentiment TEXT,
                urgency_score REAL,
                processed_at DATETIME,
                processing_status TEXT DEFAULT 'pending',
                error_message TEXT,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (thread_id) REFERENCES threads(id) ON DELETE SET NULL,
                FOREIGN KEY (sender_contact_id) REFERENCES contacts(id) ON DELETE SET NULL
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_emails_thread ON emails(thread_id)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_emails_account ON emails(account_id)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_emails_folder ON emails(folder)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_emails_received ON emails(received_at)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_emails_processing ON emails(processing_status)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_emails_sender ON emails(sender_contact_id)
            """)
        
        // MARK: - Email Metadata Table (Plugin-extensible)
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS email_metadata (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email_id TEXT NOT NULL,
                plugin_id TEXT,
                key TEXT NOT NULL,
                value TEXT,
                value_type TEXT NOT NULL DEFAULT 'string',
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (email_id) REFERENCES emails(id) ON DELETE CASCADE,
                FOREIGN KEY (plugin_id) REFERENCES plugins(id) ON DELETE SET NULL,
                UNIQUE(email_id, plugin_id, key)
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_email_metadata_email ON email_metadata(email_id)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_email_metadata_plugin ON email_metadata(plugin_id)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_email_metadata_key ON email_metadata(key)
            """)
        
        // MARK: - FTS5 Virtual Table for Full-Text Search
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS emails_fts USING fts5(
                subject,
                body_text,
                from_address,
                content='emails',
                content_rowid='rowid'
            )
            """)
        
        // Triggers to keep FTS index in sync
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS emails_ai AFTER INSERT ON emails BEGIN
                INSERT INTO emails_fts(rowid, subject, body_text, from_address)
                VALUES (new.rowid, new.subject, new.body_text, new.from_address);
            END
            """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS emails_ad AFTER DELETE ON emails BEGIN
                INSERT INTO emails_fts(emails_fts, rowid, subject, body_text, from_address)
                VALUES ('delete', old.rowid, old.subject, old.body_text, old.from_address);
            END
            """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS emails_au AFTER UPDATE ON emails BEGIN
                INSERT INTO emails_fts(emails_fts, rowid, subject, body_text, from_address)
                VALUES ('delete', old.rowid, old.subject, old.body_text, old.from_address);
                INSERT INTO emails_fts(rowid, subject, body_text, from_address)
                VALUES (new.rowid, new.subject, new.body_text, new.from_address);
            END
            """)
        
        // MARK: - Writing Profiles Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS writing_profiles (
                id TEXT PRIMARY KEY NOT NULL,
                contact_id TEXT NOT NULL,
                name TEXT NOT NULL,
                formality_level REAL DEFAULT 0.5,
                avg_sentence_length REAL,
                common_phrases TEXT DEFAULT '[]',
                vocabulary_fingerprint TEXT,
                punctuation_style TEXT,
                greeting_style TEXT,
                closing_style TEXT,
                emoji_usage REAL DEFAULT 0.0,
                response_time_avg REAL,
                timezone TEXT,
                last_analyzed_at DATETIME,
                sample_count INTEGER DEFAULT 0,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE,
                UNIQUE(contact_id, name)
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_writing_profiles_contact ON writing_profiles(contact_id)
            """)
        
        // MARK: - Response Templates Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS response_templates (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                category TEXT,
                template_text TEXT NOT NULL,
                variables TEXT DEFAULT '[]',
                usage_count INTEGER DEFAULT 0,
                success_rate REAL,
                last_used_at DATETIME,
                is_system BOOLEAN NOT NULL DEFAULT 0,
                is_active BOOLEAN NOT NULL DEFAULT 1,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_response_templates_category ON response_templates(category)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_response_templates_active ON response_templates(is_active)
            """)
        
        // MARK: - Email Embeddings Table (Vector Storage)
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS email_embeddings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email_id TEXT NOT NULL UNIQUE,
                embedding BLOB NOT NULL,
                model_name TEXT NOT NULL,
                dimensions INTEGER NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (email_id) REFERENCES emails(id) ON DELETE CASCADE
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_email_embeddings_email ON email_embeddings(email_id)
            """)
        
        // MARK: - Generic Embeddings Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS embeddings (
                id TEXT PRIMARY KEY NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                vector BLOB NOT NULL,
                dimensions INTEGER NOT NULL,
                model_name TEXT NOT NULL,
                model_version TEXT,
                content_hash TEXT,
                metadata TEXT,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(entity_type, entity_id, model_name)
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_embeddings_entity ON embeddings(entity_type, entity_id)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_embeddings_model ON embeddings(model_name)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_embeddings_hash ON embeddings(content_hash)
            """)
        
        // Virtual table for vector search (sqlite-vec)
        // Note: This requires the sqlite-vec extension to be loaded
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS vec_emails USING vec0(
                email_id TEXT PRIMARY KEY,
                embedding FLOAT[1536] distance_metric=cosine
            )
            """)
        
        // Generic virtual table for embeddings
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings USING vec0(
                embedding_id TEXT PRIMARY KEY,
                vector FLOAT[1536] distance_metric=cosine
            )
            """)
        
        // MARK: - Actions Log Table (Audit Trail)
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS actions_log (
                id TEXT PRIMARY KEY NOT NULL,
                action_type TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT,
                plugin_id TEXT,
                user_id TEXT,
                details TEXT,
                status TEXT NOT NULL DEFAULT 'pending',
                error_message TEXT,
                duration_ms INTEGER,
                ip_address TEXT,
                user_agent TEXT,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (plugin_id) REFERENCES plugins(id) ON DELETE SET NULL
            )
            """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_actions_log_type ON actions_log(action_type)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_actions_log_entity ON actions_log(entity_type, entity_id)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_actions_log_plugin ON actions_log(plugin_id)
            """)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_actions_log_created ON actions_log(created_at)
            """)
        
        // MARK: - Sync State Table
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS sync_state (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL UNIQUE,
                last_sync_at DATETIME,
                last_sync_token TEXT,
                sync_cursor TEXT,
                items_synced INTEGER DEFAULT 0,
                items_failed INTEGER DEFAULT 0,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)
        
        // MARK: - Settings Table (App-level settings)
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS settings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key TEXT NOT NULL UNIQUE,
                value TEXT,
                value_type TEXT NOT NULL DEFAULT 'string',
                description TEXT,
                is_encrypted BOOLEAN NOT NULL DEFAULT 0,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)
        
        // Insert default settings
        try db.execute(sql: """
            INSERT OR IGNORE INTO settings (key, value, value_type, description) VALUES
            ('ai.model.default', 'gpt-4', 'string', 'Default AI model for processing'),
            ('ai.temperature', '0.7', 'float', 'AI temperature (0.0-1.0)'),
            ('processing.auto_summarize', 'true', 'boolean', 'Auto-summarize incoming emails'),
            ('processing.auto_categorize', 'true', 'boolean', 'Auto-categorize incoming emails'),
            ('notifications.enabled', 'true', 'boolean', 'Enable push notifications'),
            ('privacy.anonymize_logs', 'false', 'boolean', 'Anonymize data in action logs')
            """)
    }
}

// MARK: - Migration Protocol

/// Protocol for database migrations
protocol DatabaseMigration {
    var version: Int64 { get }
    var name: String { get }
    func migrate(_ db: Database) throws
}
