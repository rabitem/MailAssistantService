import Foundation
import GRDB

/// GRDB Record for the plugins table
public struct PluginRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "plugins"
    
    // MARK: - Primary Key
    public var id: String
    
    // MARK: - Plugin Info
    public var name: String
    public var version: String
    public var bundleId: String
    public var author: String?
    public var description: String?
    
    // MARK: - Configuration
    public var permissions: String // JSON array of permission strings
    public var settingsSchema: String? // JSON schema for settings
    public var defaultSettings: String? // JSON default settings
    
    // MARK: - Status
    public var isEnabled: Bool
    public var isSystem: Bool
    
    // MARK: - Timestamps
    public var installedAt: Date
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case bundleId = "bundle_id"
        case author
        case description
        case permissions
        case isEnabled = "is_enabled"
        case isSystem = "is_system"
        case settingsSchema = "settings_schema"
        case defaultSettings = "default_settings"
        case installedAt = "installed_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        version: String,
        bundleId: String,
        author: String? = nil,
        description: String? = nil,
        permissions: [PluginPermission] = [],
        settingsSchema: [String: Any]? = nil,
        defaultSettings: [String: Any]? = nil,
        isEnabled: Bool = true,
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.bundleId = bundleId
        self.author = author
        self.description = description
        self.permissions = (try? JSONSerialization.data(withJSONObject: permissions.map(\.rawValue)))?.utf8String ?? "[]"
        self.settingsSchema = settingsSchema.flatMap { try? JSONSerialization.data(withJSONObject: $0) }?.utf8String
        self.defaultSettings = defaultSettings.flatMap { try? JSONSerialization.data(withJSONObject: $0) }?.utf8String
        self.isEnabled = isEnabled
        self.isSystem = isSystem
        self.installedAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - PersistableRecord
    
    public func willInsert(_ db: Database) throws {
        var mutableSelf = self
        mutableSelf.installedAt = Date()
        mutableSelf.updatedAt = Date()
    }
    
    public func willUpdate(_ db: Database, columns: Set<String>) throws {
        var mutableSelf = self
        mutableSelf.updatedAt = Date()
    }
    
    // MARK: - JSON Helpers
    
    public func getPermissions() -> [PluginPermission] {
        guard let data = permissions.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return strings.compactMap { PluginPermission(rawValue: $0) }
    }
    
    public func getSettingsSchema() -> [String: Any]? {
        guard let schema = settingsSchema,
              let data = schema.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    public func getDefaultSettings() -> [String: Any]? {
        guard let settings = defaultSettings,
              let data = settings.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

// MARK: - Plugin Permission Enum

public enum PluginPermission: String, Codable, CaseIterable {
    case readEmails = "read_emails"
    case writeEmails = "write_emails"
    case sendEmails = "send_emails"
    case readContacts = "read_contacts"
    case writeContacts = "write_contacts"
    case accessCalendar = "access_calendar"
    case networkAccess = "network_access"
    case fileSystemAccess = "filesystem_access"
    case notifications = "notifications"
    case aiProcessing = "ai_processing"
    case vectorSearch = "vector_search"
    case settingsAccess = "settings_access"
}

// MARK: - Associations

extension PluginRecord {
    /// Association to plugin data
    public static let data = hasMany(PluginDataRecord.self, using: ForeignKey(["plugin_id"]))
    
    /// Association to email metadata
    public static let emailMetadata = hasMany(EmailMetadataRecord.self, using: ForeignKey(["plugin_id"]))
    
    /// Association to action logs
    public static let actionLogs = hasMany(ActionLogRecord.self, using: ForeignKey(["plugin_id"]))
}

// MARK: - Query Extensions

extension PluginRecord {
    /// Query for enabled plugins
    public static func enabled() -> QueryInterfaceRequest<PluginRecord> {
        filter(Column("is_enabled") == true)
    }
    
    /// Query for system plugins
    public static func system() -> QueryInterfaceRequest<PluginRecord> {
        filter(Column("is_system") == true)
    }
    
    /// Query by bundle ID
    public static func withBundleId(_ bundleId: String) -> QueryInterfaceRequest<PluginRecord> {
        filter(Column("bundle_id") == bundleId)
    }
    
    /// Query for plugins with a specific permission
    public static func withPermission(_ permission: PluginPermission) -> QueryInterfaceRequest<PluginRecord> {
        filter(sql: "permissions LIKE ?", arguments: ["%\(permission.rawValue)%"])
    }
    
    /// Search plugins by name
    public static func search(byName query: String) -> QueryInterfaceRequest<PluginRecord> {
        filter(Column("name").like("%\(query)%"))
    }
}

// MARK: - Plugin Data Record

public struct PluginDataRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable {
    public static let databaseTableName = "plugin_data"
    
    public var id: Int64?
    public var pluginId: String
    public var key: String
    public var value: String?
    public var createdAt: Date
    public var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pluginId = "plugin_id"
        case key
        case value
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
    
    // MARK: - Typed Value Access
    
    public func getString() -> String? {
        return value
    }
    
    public func getInt() -> Int? {
        guard let value = value else { return nil }
        return Int(value)
    }
    
    public func getDouble() -> Double? {
        guard let value = value else { return nil }
        return Double(value)
    }
    
    public func getBool() -> Bool? {
        guard let value = value?.lowercased() else { return nil }
        return ["true", "1", "yes"].contains(value)
    }
    
    public func getJSON<T: Decodable>(_ type: T.Type) -> T? {
        guard let value = value,
              let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    // MARK: - Initialization Helpers
    
    public static func create(pluginId: String, key: String, value: String) -> PluginDataRecord {
        return PluginDataRecord(
            id: nil,
            pluginId: pluginId,
            key: key,
            value: value,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    public static func create(pluginId: String, key: String, value: Int) -> PluginDataRecord {
        return create(pluginId: pluginId, key: key, value: String(value))
    }
    
    public static func create(pluginId: String, key: String, value: Double) -> PluginDataRecord {
        return create(pluginId: pluginId, key: key, value: String(value))
    }
    
    public static func create(pluginId: String, key: String, value: Bool) -> PluginDataRecord {
        return create(pluginId: pluginId, key: key, value: value ? "true" : "false")
    }
    
    public static func create<T: Encodable>(pluginId: String, key: String, value: T) -> PluginDataRecord? {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return create(pluginId: pluginId, key: key, value: string)
    }
}

// MARK: - Query Extensions for PluginData

extension PluginDataRecord {
    /// Query for data by plugin ID
    public static func forPlugin(_ pluginId: String) -> QueryInterfaceRequest<PluginDataRecord> {
        filter(Column("plugin_id") == pluginId)
    }
    
    /// Query for specific key
    public static func withKey(_ key: String) -> QueryInterfaceRequest<PluginDataRecord> {
        filter(Column("key") == key)
    }
    
    /// Query for data by plugin and key
    public static func forPlugin(_ pluginId: String, key: String) -> QueryInterfaceRequest<PluginDataRecord> {
        filter(Column("plugin_id") == pluginId && Column("key") == key)
    }
}
