import Foundation
import GRDB

/// GRDB Record for the actions_log table
/// Comprehensive audit trail for all system actions
public struct ActionLogRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "actions_log"
    
    // MARK: - Primary Key
    public var id: String
    
    // MARK: - Action Classification
    public var actionType: ActionType
    public var entityType: EntityType
    public var entityId: String?
    
    // MARK: - Actor Information
    public var pluginId: String?
    public var userId: String?
    
    // MARK: - Action Details
    /// JSON object with action-specific details
    public var details: String?
    
    // MARK: - Status
    public var status: ActionStatus
    public var errorMessage: String?
    
    // MARK: - Performance Metrics
    public var durationMs: Int?
    
    // MARK: - Client Information
    public var ipAddress: String?
    public var userAgent: String?
    
    // MARK: - Timestamp
    public var createdAt: Date
    
    // MARK: - Enums
    
    public enum ActionType: String, Codable, DatabaseValueConvertible, CaseIterable {
        // Email actions
        case emailReceived = "email_received"
        case emailSent = "email_sent"
        case emailProcessed = "email_processed"
        case emailSummarized = "email_summarized"
        case emailCategorized = "email_categorized"
        case emailArchived = "email_archived"
        case emailDeleted = "email_deleted"
        case emailMoved = "email_moved"
        case emailFlagged = "email_flagged"
        case emailRead = "email_read"
        
        // AI actions
        case aiSuggestionGenerated = "ai_suggestion_generated"
        case aiResponseGenerated = "ai_response_generated"
        case aiAnalysisCompleted = "ai_analysis_completed"
        case aiEmbeddingCreated = "ai_embedding_created"
        case aiVectorSearch = "ai_vector_search"
        
        // Plugin actions
        case pluginInstalled = "plugin_installed"
        case pluginUninstalled = "plugin_uninstalled"
        case pluginEnabled = "plugin_enabled"
        case pluginDisabled = "plugin_disabled"
        case pluginExecuted = "plugin_executed"
        case pluginSettingsChanged = "plugin_settings_changed"
        
        // Contact actions
        case contactCreated = "contact_created"
        case contactUpdated = "contact_updated"
        case contactMerged = "contact_merged"
        case contactAnalyzed = "contact_analyzed"
        
        // System actions
        case syncStarted = "sync_started"
        case syncCompleted = "sync_completed"
        case syncFailed = "sync_failed"
        case settingsChanged = "settings_changed"
        case exportPerformed = "export_performed"
        case importPerformed = "import_performed"
        case backupCreated = "backup_created"
        case backupRestored = "backup_restored"
        
        // Security actions
        case login = "login"
        case logout = "logout"
        case tokenRefreshed = "token_refreshed"
        case permissionDenied = "permission_denied"
        
        // Error actions
        case error = "error"
        case warning = "warning"
    }
    
    public enum EntityType: String, Codable, DatabaseValueConvertible, CaseIterable {
        case email = "email"
        case contact = "contact"
        case thread = "thread"
        case plugin = "plugin"
        case template = "template"
        case profile = "profile"
        case setting = "setting"
        case system = "system"
        case user = "user"
        case unknown = "unknown"
    }
    
    public enum ActionStatus: String, Codable, DatabaseValueConvertible {
        case pending = "pending"
        case success = "success"
        case failed = "failed"
        case cancelled = "cancelled"
        case retrying = "retrying"
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case actionType = "action_type"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case pluginId = "plugin_id"
        case userId = "user_id"
        case details
        case status
        case errorMessage = "error_message"
        case durationMs = "duration_ms"
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case createdAt = "created_at"
    }
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        actionType: ActionType,
        entityType: EntityType,
        entityId: String? = nil,
        pluginId: String? = nil,
        userId: String? = nil,
        details: [String: Any]? = nil,
        status: ActionStatus = .success,
        errorMessage: String? = nil,
        durationMs: Int? = nil,
        ipAddress: String? = nil,
        userAgent: String? = nil
    ) {
        self.id = id
        self.actionType = actionType
        self.entityType = entityType
        self.entityId = entityId
        self.pluginId = pluginId
        self.userId = userId
        self.details = details.flatMap { dict -> String? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        self.status = status
        self.errorMessage = errorMessage
        self.durationMs = durationMs
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.createdAt = Date()
    }
    
    // MARK: - JSON Helpers
    
    public func getDetails() -> [String: Any]? {
        guard let details = details,
              let data = details.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    // MARK: - Computed Properties
    
    /// Returns a human-readable description of the action
    public var description: String {
        var components: [String] = []
        components.append(actionType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        
        if let entity = entityId {
            components.append("\(entityType.rawValue): \(entity.prefix(8))...")
        }
        
        if let plugin = pluginId {
            components.append("(via \(plugin.prefix(8)))")
        }
        
        return components.joined(separator: " ")
    }
    
    /// Returns true if the action was successful
    public var isSuccess: Bool {
        status == .success
    }
    
    /// Returns true if this is an error action
    public var isError: Bool {
        status == .failed || actionType == .error
    }
}

// MARK: - Associations

extension ActionLogRecord {
    /// Association to plugin
    public static let plugin = belongsTo(PluginRecord.self, using: ForeignKey(["plugin_id"]))
}

// MARK: - Query Extensions

extension ActionLogRecord {
    /// Query for specific action type
    public static func ofType(_ type: ActionType) -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("action_type") == type.rawValue)
    }
    
    /// Query for specific entity
    public static func forEntity(type: EntityType, id: String) -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("entity_type") == type.rawValue && Column("entity_id") == id)
    }
    
    /// Query for plugin actions
    public static func forPlugin(_ pluginId: String) -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("plugin_id") == pluginId)
    }
    
    /// Query for user actions
    public static func forUser(_ userId: String) -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("user_id") == userId)
    }
    
    /// Query for failed actions
    public static func failed() -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("status") == ActionStatus.failed.rawValue)
    }
    
    /// Query for successful actions
    public static func successful() -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("status") == ActionStatus.success.rawValue)
    }
    
    /// Query for actions in a time range
    public static func inTimeRange(from: Date, to: Date) -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("created_at") >= from && Column("created_at") <= to)
    }
    
    /// Query for recent actions
    public static func recent(limit: Int = 100) -> QueryInterfaceRequest<ActionLogRecord> {
        order(Column("created_at").desc)
            .limit(limit)
    }
    
    /// Query for error actions
    public static func errors() -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("action_type") == ActionType.error.rawValue ||
               Column("status") == ActionStatus.failed.rawValue)
            .order(Column("created_at").desc)
    }
    
    /// Query for slow actions (above duration threshold)
    public static func slow(thresholdMs: Int) -> QueryInterfaceRequest<ActionLogRecord> {
        filter(Column("duration_ms") >= thresholdMs)
            .order(Column("duration_ms").desc)
    }
    
    /// Query for actions by multiple types
    public static func ofTypes(_ types: [ActionType]) -> QueryInterfaceRequest<ActionLogRecord> {
        let typeStrings = types.map(\.rawValue)
        return filter(typeStrings.contains(Column("action_type")))
    }
    
    /// Query grouped statistics by action type
    public static func statisticsByType(since: Date) async throws -> [(type: ActionType, count: Int)] {
        // Note: This would need to be executed in a database context
        // This is a placeholder for the concept
        return []
    }
}

// MARK: - Action Logger

/// Convenience class for logging actions
public actor ActionLogger {
    private let dbQueue: DatabaseQueue
    
    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    /// Log an action
    public func log(_ action: ActionLogRecord) async throws {
        try await dbQueue.write { db in
            try action.insert(db)
        }
    }
    
    /// Quick log helper for success
    public func logSuccess(
        actionType: ActionLogRecord.ActionType,
        entityType: ActionLogRecord.EntityType,
        entityId: String? = nil,
        pluginId: String? = nil,
        details: [String: Any]? = nil
    ) async throws {
        let action = ActionLogRecord(
            actionType: actionType,
            entityType: entityType,
            entityId: entityId,
            pluginId: pluginId,
            details: details,
            status: .success
        )
        try await log(action)
    }
    
    /// Quick log helper for failure
    public func logFailure(
        actionType: ActionLogRecord.ActionType,
        entityType: ActionLogRecord.EntityType,
        entityId: String? = nil,
        pluginId: String? = nil,
        error: Error,
        details: [String: Any]? = nil
    ) async throws {
        var allDetails = details ?? [:]
        allDetails["error_type"] = String(describing: type(of: error))
        allDetails["error_description"] = error.localizedDescription
        
        let action = ActionLogRecord(
            actionType: actionType,
            entityType: entityType,
            entityId: entityId,
            pluginId: pluginId,
            details: allDetails,
            status: .failed,
            errorMessage: error.localizedDescription
        )
        try await log(action)
    }
    
    /// Log with timing
    public func logWithTiming<T>(
        actionType: ActionLogRecord.ActionType,
        entityType: ActionLogRecord.EntityType,
        entityId: String? = nil,
        pluginId: String? = nil,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        do {
            let result = try await operation()
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            
            let action = ActionLogRecord(
                actionType: actionType,
                entityType: entityType,
                entityId: entityId,
                pluginId: pluginId,
                status: .success,
                durationMs: duration
            )
            try? await log(action)
            
            return result
        } catch {
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            
            let action = ActionLogRecord(
                actionType: actionType,
                entityType: entityType,
                entityId: entityId,
                pluginId: pluginId,
                status: .failed,
                errorMessage: error.localizedDescription,
                durationMs: duration
            )
            try? await log(action)
            
            throw error
        }
    }
}

// MARK: - Data Extension

private extension Data {
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}
