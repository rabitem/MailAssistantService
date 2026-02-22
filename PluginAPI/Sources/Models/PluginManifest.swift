import Foundation

/// Plugin manifest containing metadata and configuration
public struct PluginManifest: Codable, Sendable {
    public let id: PluginID
    public let name: String
    public let version: String
    public let description: String
    public let author: String
    public let category: PluginCategory
    public let permissions: [Permission]
    public let dependencies: [PluginDependency]
    public let entryPoint: String
    public let minAppVersion: String?
    public let settingsSchema: [SettingSchema]?
    
    public init(
        id: PluginID,
        name: String,
        version: String,
        description: String,
        author: String,
        category: PluginCategory,
        permissions: [Permission] = [],
        dependencies: [PluginDependency] = [],
        entryPoint: String,
        minAppVersion: String? = nil,
        settingsSchema: [SettingSchema]? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.category = category
        self.permissions = permissions
        self.dependencies = dependencies
        self.entryPoint = entryPoint
        self.minAppVersion = minAppVersion
        self.settingsSchema = settingsSchema
    }
}

public enum PluginCategory: String, Codable, Sendable, CaseIterable {
    case aiProvider = "ai_provider"
    case automation = "automation"
    case integration = "integration"
    case security = "security"
    case utility = "utility"
    case core = "core"
}

public struct PluginDependency: Codable, Sendable {
    public let pluginId: PluginID
    public let versionConstraint: String
    public let optional: Bool
    
    public init(pluginId: PluginID, versionConstraint: String, optional: Bool = false) {
        self.pluginId = pluginId
        self.versionConstraint = versionConstraint
        self.optional = optional
    }
}

public struct SettingSchema: Codable, Sendable {
    public let key: String
    public let type: SettingType
    public let label: String
    public let description: String?
    public let defaultValue: String?
    public let required: Bool
    public let options: [String: String]?
    
    public init(
        key: String,
        type: SettingType,
        label: String,
        description: String? = nil,
        defaultValue: String? = nil,
        required: Bool = false,
        options: [String: String]? = nil
    ) {
        self.key = key
        self.type = type
        self.label = label
        self.description = description
        self.defaultValue = defaultValue
        self.required = required
        self.options = options
    }
}

public enum SettingType: String, Codable, Sendable {
    case string
    case boolean
    case number
    case integer
    case email
    case password
    case select
    case multiselect
    case color
}
