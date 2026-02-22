import Foundation

// MARK: - Integration Plugin

/// Protocol for plugins that integrate with external services (calendars, task managers, CRMs, etc.)
public protocol IntegrationPlugin: Plugin {
    /// The type of external service this plugin integrates with
    var integrationType: IntegrationType { get }
    
    /// Current connection status
    var connectionStatus: ConnectionStatus { get async }
    
    /// Check if the integration is available and properly configured
    func isAvailable() async -> Bool
    
    /// Authenticate with the external service
    func authenticate() async throws -> AuthResult
    
    /// Disconnect from the external service
    func disconnect() async throws
    
    /// Sync data between the app and external service
    func sync(payload: SyncPayload) async throws -> SyncResult
    
    /// Fetch data from the external service
    func fetch(request: FetchRequest) async throws -> FetchResult
    
    /// Push data to the external service
    func push(data: PushData) async throws -> PushResult
    
    /// Subscribe to real-time updates (if supported)
    func subscribeToUpdates() -> AsyncStream<ExternalEvent>?
}

// MARK: - Integration Type

public enum IntegrationType: String, Codable, Sendable, CaseIterable {
    case calendar = "calendar"
    case taskManager = "task_manager"
    case crm = "crm"
    case cloudStorage = "cloud_storage"
    case communication = "communication"
    case projectManagement = "project_management"
    case noteTaking = "note_taking"
    case contactManager = "contact_manager"
    case aiService = "ai_service"
    case custom = "custom"
}

// MARK: - Connection Status

public enum ConnectionStatus: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case error
    case unauthorized
    case limited
    
    public var isConnected: Bool {
        self == .connected || self == .limited
    }
}

// MARK: - Auth Result

public struct AuthResult: Codable, Sendable {
    public let success: Bool
    public let accessToken: String?
    public let refreshToken: String?
    public let expiresAt: Date?
    public let userInfo: [String: AnyCodable]?
    public let error: String?
    
    public init(
        success: Bool,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        userInfo: [String: AnyCodable]? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userInfo = userInfo
        self.error = error
    }
}

// MARK: - Sync Payload

/// Data to be synchronized
public struct SyncPayload: Sendable {
    /// Direction of sync
    public let direction: SyncDirection
    
    /// Type of data to sync
    public let dataType: SyncDataType
    
    /// Items to sync (for push operations)
    public let items: [SyncItem]?
    
    /// Last sync timestamp (for incremental sync)
    public let since: Date?
    
    /// Conflict resolution strategy
    public let conflictResolution: ConflictResolution
    
    /// Maximum items to sync
    public let limit: Int?
    
    public init(
        direction: SyncDirection,
        dataType: SyncDataType,
        items: [SyncItem]? = nil,
        since: Date? = nil,
        conflictResolution: ConflictResolution = .newestWins,
        limit: Int? = nil
    ) {
        self.direction = direction
        self.dataType = dataType
        self.items = items
        self.since = since
        self.conflictResolution = conflictResolution
        self.limit = limit
    }
}

// MARK: - Sync Direction

public enum SyncDirection: String, Codable, Sendable {
    case push // App to external
    case pull // External to app
    case bidirectional
}

// MARK: - Sync Data Type

public enum SyncDataType: String, Codable, Sendable {
    case events
    case tasks
    case contacts
    case notes
    case files
    case emails
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = SyncDataType(rawValue: rawValue) {
            self = standard
        } else {
            self = .custom(rawValue)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .custom(let value):
            try container.encode(value)
        default:
            try container.encode(self.rawValue)
        }
    }
}

// MARK: - Sync Item

public struct SyncItem: Codable, Sendable, Identifiable {
    public let id: String
    public let externalID: String?
    public let data: [String: AnyCodable]
    public let modifiedAt: Date
    public let deleted: Bool
    
    public init(
        id: String,
        externalID: String? = nil,
        data: [String: AnyCodable],
        modifiedAt: Date,
        deleted: Bool = false
    ) {
        self.id = id
        self.externalID = externalID
        self.data = data
        self.modifiedAt = modifiedAt
        self.deleted = deleted
    }
}

// MARK: - Conflict Resolution

public enum ConflictResolution: String, Codable, Sendable {
    case newestWins = "newest_wins"
    case externalWins = "external_wins"
    case localWins = "local_wins"
    case manual = "manual"
    case merge = "merge"
}

// MARK: - Sync Result

public struct SyncResult: Codable, Sendable {
    public let success: Bool
    public let syncedItems: Int
    public let conflicts: [SyncConflict]
    public let errors: [SyncError]
    public let nextSyncToken: String?
    public let hasMore: Bool
    
    public init(
        success: Bool,
        syncedItems: Int,
        conflicts: [SyncConflict] = [],
        errors: [SyncError] = [],
        nextSyncToken: String? = nil,
        hasMore: Bool = false
    ) {
        self.success = success
        self.syncedItems = syncedItems
        self.conflicts = conflicts
        self.errors = errors
        self.nextSyncToken = nextSyncToken
        self.hasMore = hasMore
    }
}

// MARK: - Sync Conflict

public struct SyncConflict: Codable, Sendable {
    public let itemID: String
    public let localData: [String: AnyCodable]
    public let externalData: [String: AnyCodable]
    public let field: String?
    
    public init(
        itemID: String,
        localData: [String: AnyCodable],
        externalData: [String: AnyCodable],
        field: String? = nil
    ) {
        self.itemID = itemID
        self.localData = localData
        self.externalData = externalData
        self.field = field
    }
}

// MARK: - Sync Error

public struct SyncError: Codable, Sendable {
    public let itemID: String?
    public let code: String
    public let message: String
    public let retryable: Bool
    
    public init(
        itemID: String? = nil,
        code: String,
        message: String,
        retryable: Bool = false
    ) {
        self.itemID = itemID
        self.code = code
        self.message = message
        self.retryable = retryable
    }
}

// MARK: - Fetch Request

public struct FetchRequest: Sendable {
    public let dataType: SyncDataType
    public let query: String?
    public let filters: [String: AnyCodable]
    public let sortBy: String?
    public let sortOrder: SortOrder
    public let limit: Int?
    public let offset: Int?
    
    public init(
        dataType: SyncDataType,
        query: String? = nil,
        filters: [String: AnyCodable] = [:],
        sortBy: String? = nil,
        sortOrder: SortOrder = .descending,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.dataType = dataType
        self.query = query
        self.filters = filters
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - Sort Order

public enum SortOrder: String, Codable, Sendable {
    case ascending
    case descending
}

// MARK: - Fetch Result

public struct FetchResult: Codable, Sendable {
    public let items: [SyncItem]
    public let totalCount: Int
    public let hasMore: Bool
    public let nextOffset: Int?
    
    public init(
        items: [SyncItem],
        totalCount: Int,
        hasMore: Bool,
        nextOffset: Int? = nil
    ) {
        self.items = items
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.nextOffset = nextOffset
    }
}

// MARK: - Push Data

public struct PushData: Sendable {
    public let dataType: SyncDataType
    public let items: [SyncItem]
    public let operation: PushOperation
    
    public init(
        dataType: SyncDataType,
        items: [SyncItem],
        operation: PushOperation = .createOrUpdate
    ) {
        self.dataType = dataType
        self.items = items
        self.operation = operation
    }
}

// MARK: - Push Operation

public enum PushOperation: String, Codable, Sendable {
    case create
    case update
    case createOrUpdate = "create_or_update"
    case delete
}

// MARK: - Push Result

public struct PushResult: Codable, Sendable {
    public let success: Bool
    public let created: [String]
    public let updated: [String]
    public let failed: [PushFailure]
    
    public init(
        success: Bool,
        created: [String] = [],
        updated: [String] = [],
        failed: [PushFailure] = []
    ) {
        self.success = success
        self.created = created
        self.updated = updated
        self.failed = failed
    }
}

// MARK: - Push Failure

public struct PushFailure: Codable, Sendable {
    public let itemID: String
    public let error: String
    public let retryable: Bool
    
    public init(itemID: String, error: String, retryable: Bool = false) {
        self.itemID = itemID
        self.error = error
        self.retryable = retryable
    }
}

// MARK: - External Event

/// Events from external services (webhooks, real-time updates)
public struct ExternalEvent: Codable, Sendable {
    public let type: String
    public let dataType: SyncDataType
    public let externalID: String
    public let data: [String: AnyCodable]
    public let timestamp: Date
    
    public init(
        type: String,
        dataType: SyncDataType,
        externalID: String,
        data: [String: AnyCodable],
        timestamp: Date
    ) {
        self.type = type
        self.dataType = dataType
        self.externalID = externalID
        self.data = data
        self.timestamp = timestamp
    }
}

// MARK: - Rate Limit Info

public struct RateLimitInfo: Codable, Sendable {
    public let limit: Int
    public let remaining: Int
    public let resetAt: Date
    
    public var isLimited: Bool {
        remaining <= 0
    }
}
