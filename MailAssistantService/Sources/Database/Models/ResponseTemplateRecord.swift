import Foundation
import GRDB

/// GRDB Record for the response_templates table
/// Stores learned and manually created response templates
public struct ResponseTemplateRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "response_templates"
    
    // MARK: - Primary Key
    public var id: String
    
    // MARK: - Template Info
    public var name: String
    public var category: String?
    public var templateText: String
    
    // MARK: - Variables
    /// JSON array of variable names used in the template
    public var variables: String?
    
    // MARK: - Usage Statistics
    public var usageCount: Int
    public var successRate: Double?
    public var lastUsedAt: Date?
    
    // MARK: - Status
    public var isSystem: Bool
    public var isActive: Bool
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case templateText = "template_text"
        case variables
        case usageCount = "usage_count"
        case successRate = "success_rate"
        case lastUsedAt = "last_used_at"
        case isSystem = "is_system"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        category: String? = nil,
        templateText: String,
        variables: [String] = [],
        isSystem: Bool = false,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.templateText = templateText
        self.variables = (try? JSONEncoder().encode(variables))?.utf8String
        self.usageCount = 0
        self.successRate = nil
        self.lastUsedAt = nil
        self.isSystem = isSystem
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - PersistableRecord
    
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        // Row inserted successfully, timestamps already set in init
    }
    
    // MARK: - JSON Helpers
    
    public func getVariables() -> [String] {
        guard let vars = variables,
              let data = vars.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    /// Extracts variables from template text using {{variable}} syntax
    public static func extractVariables(from text: String) -> [String] {
        let pattern = #"\{\{(\w+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }
    
    // MARK: - Template Rendering
    
    /// Renders the template with provided variable values
    /// - Parameters:
    ///   - values: Dictionary of variable names to values
    /// - Returns: Rendered template text
    public func render(with values: [String: String]) -> String {
        var result = templateText
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
    
    /// Validates that all required variables are provided
    /// - Parameter values: Dictionary of variable names to values
    /// - Returns: Array of missing variable names
    public func validateVariables(_ values: [String: String]) -> [String] {
        let requiredVars = getVariables()
        return requiredVars.filter { values[$0] == nil }
    }
    
    // MARK: - Statistics
    
    /// Records a successful use of the template
    /// Call this and then save the record
    public mutating func recordUsage(success: Bool) {
        usageCount += 1
        lastUsedAt = Date()
        
        // Update success rate using exponential moving average
        let alpha = 0.3 // Weight for new observation
        let currentRate = successRate ?? 0.5
        let newRate = success ? (currentRate * (1 - alpha) + alpha) : (currentRate * (1 - alpha))
        successRate = newRate
    }
    
    /// Returns a reliability score based on usage and success rate
    public var reliabilityScore: Double {
        let rate = successRate ?? 0.5
        let usageWeight = min(Double(usageCount) / 10.0, 1.0) // Max weight at 10 uses
        return rate * usageWeight
    }
}

// MARK: - Query Extensions

extension ResponseTemplateRecord {
    /// Query for active templates
    public static func active() -> QueryInterfaceRequest<ResponseTemplateRecord> {
        filter(Column("is_active") == true)
    }
    
    /// Query for system templates
    public static func system() -> QueryInterfaceRequest<ResponseTemplateRecord> {
        filter(Column("is_system") == true)
    }
    
    /// Query for user templates (non-system)
    public static func user() -> QueryInterfaceRequest<ResponseTemplateRecord> {
        filter(Column("is_system") == false)
    }
    
    /// Query by category
    public static func inCategory(_ category: String) -> QueryInterfaceRequest<ResponseTemplateRecord> {
        filter(Column("category") == category)
    }
    
    /// Query templates by name search
    public static func search(byName query: String) -> QueryInterfaceRequest<ResponseTemplateRecord> {
        filter(Column("name").like("%\(query)%"))
    }
    
    /// Query templates by content search
    public static func search(byContent query: String) -> QueryInterfaceRequest<ResponseTemplateRecord> {
        filter(Column("template_text").like("%\(query)%"))
    }
    
    /// Query most frequently used templates
    public static func mostUsed() -> QueryInterfaceRequest<ResponseTemplateRecord> {
        order(Column("usage_count").desc)
    }
    
    /// Query most successful templates
    public static func mostSuccessful() -> QueryInterfaceRequest<ResponseTemplateRecord> {
        order(Column("success_rate").desc)
    }
    
    /// Query recently used templates
    public static func recentlyUsed() -> QueryInterfaceRequest<ResponseTemplateRecord> {
        order(Column("last_used_at").desc)
    }
    
    /// Query templates by minimum reliability score
    public static func withMinReliability(_ score: Double) -> QueryInterfaceRequest<ResponseTemplateRecord> {
        // Note: This is a simplified filter; in practice you'd compute in Swift
        filter(Column("success_rate") >= score && Column("usage_count") >= 5)
    }
    
    /// Query templates for a specific context
    public static func forContext(context: TemplateContext) -> QueryInterfaceRequest<ResponseTemplateRecord> {
        var query = active()
        
        if let category = context.category {
            query = query.inCategory(category)
        }
        
        return query
    }
}

// MARK: - Template Context

/// Context for selecting appropriate templates
public struct TemplateContext {
    public let category: String?
    public let contactId: String?
    public let emailSubject: String?
    public let sentiment: String?
    public let urgency: Double?
    
    public init(
        category: String? = nil,
        contactId: String? = nil,
        emailSubject: String? = nil,
        sentiment: String? = nil,
        urgency: Double? = nil
    ) {
        self.category = category
        self.contactId = contactId
        self.emailSubject = emailSubject
        self.sentiment = sentiment
        self.urgency = urgency
    }
}

// MARK: - Template Builder

/// Helper for building templates programmatically
public struct TemplateBuilder {
    private var name: String = ""
    private var category: String?
    private var components: [String] = []
    private var variables: Set<String> = []
    
    public init() {}
    
    public mutating func setName(_ name: String) -> Self {
        self.name = name
        return self
    }
    
    public mutating func setCategory(_ category: String) -> Self {
        self.category = category
        return self
    }
    
    public mutating func addText(_ text: String) -> Self {
        components.append(text)
        return self
    }
    
    public mutating func addVariable(_ name: String, placeholder: String? = nil) -> Self {
        variables.insert(name)
        let display = placeholder ?? name
        components.append("{{\(display)}}")
        return self
    }
    
    public mutating func addGreeting() -> Self {
        components.append("{{greeting}}")
        variables.insert("greeting")
        return self
    }
    
    public mutating func addClosing() -> Self {
        components.append("\n\n{{closing}}")
        variables.insert("closing")
        return self
    }
    
    public mutating func addSignature() -> Self {
        components.append("\n{{signature}}")
        variables.insert("signature")
        return self
    }
    
    public func build() -> ResponseTemplateRecord {
        let text = components.joined()
        return ResponseTemplateRecord(
            name: name,
            category: category,
            templateText: text,
            variables: Array(variables)
        )
    }
}

// MARK: - Data Extension

private extension Data {
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}
