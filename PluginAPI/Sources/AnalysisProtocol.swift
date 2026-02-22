import Foundation

// MARK: - Analysis Plugin

/// Protocol for plugins that analyze emails and provide insights
public protocol AnalysisPlugin: Plugin {
    /// The types of analysis this plugin provides
    var supportedAnalysisTypes: [AnalysisType] { get }
    
    /// Analyze an email and return results
    func analyze(email: Email, types: [AnalysisType]) async throws -> AnalysisResult
    
    /// Batch analyze multiple emails
    func analyzeBatch(emails: [Email], types: [AnalysisType]) async throws -> [AnalysisResult]
    
    /// Check if this plugin can analyze the given email
    func canAnalyze(_ email: Email) async -> Bool
    
    /// Get estimated processing time for an email
    func estimatedProcessingTime(for email: Email) -> TimeInterval
}

// MARK: - Analysis Type

/// Types of analysis that can be performed on emails
public enum AnalysisType: String, Codable, Sendable, CaseIterable {
    case sentiment = "sentiment"
    case urgency = "urgency"
    case category = "category"
    case summary = "summary"
    case actionItems = "action_items"
    case tone = "tone"
    case readability = "readability"
    case entities = "entities"
    case intent = "intent"
    case priority = "priority"
    case spam = "spam"
    case phishing = "phishing"
    case language = "language"
    case keyTopics = "key_topics"
    case sentimentTrend = "sentiment_trend"
    case responseSuggestions = "response_suggestions"
}

// MARK: - Analysis Result

/// The result of analyzing an email
public struct AnalysisResult: Codable, Sendable, Identifiable {
    public let id: UUID
    public let emailID: UUID
    public let analyzedAt: Date
    public let pluginID: String
    public let insights: [Insight]
    public let processingTime: TimeInterval
    public let confidence: Double
    
    public init(
        id: UUID = UUID(),
        emailID: UUID,
        analyzedAt: Date = Date(),
        pluginID: String,
        insights: [Insight],
        processingTime: TimeInterval,
        confidence: Double
    ) {
        self.id = id
        self.emailID = emailID
        self.analyzedAt = analyzedAt
        self.pluginID = pluginID
        self.insights = insights
        self.processingTime = processingTime
        self.confidence = confidence
    }
}

// MARK: - Insight

/// A single insight from email analysis
public struct Insight: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: AnalysisType
    public let title: String
    public let description: String
    public let value: InsightValue
    public let confidence: Double
    public let metadata: [String: AnyCodable]
    
    public init(
        id: UUID = UUID(),
        type: AnalysisType,
        title: String,
        description: String,
        value: InsightValue,
        confidence: Double,
        metadata: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.value = value
        self.confidence = confidence
        self.metadata = metadata
    }
}

// MARK: - Insight Value

/// The value of an insight, supporting multiple data types
public enum InsightValue: Codable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([InsightValue])
    case dictionary([String: InsightValue])
    case none
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .integer(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .boolean(bool)
        } else if let array = try? container.decode([InsightValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: InsightValue].self) {
            self = .dictionary(dict)
        } else {
            self = .none
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .dictionary(let dict):
            try container.encode(dict)
        case .none:
            try container.encodeNil()
        }
    }
}

// MARK: - Common Insight Types

/// Predefined insight structures for common analysis types

public struct SentimentInsight: Codable, Sendable {
    public let score: Double // -1.0 to 1.0
    public let label: SentimentLabel
    public let explanation: String
    
    public enum SentimentLabel: String, Codable, Sendable {
        case veryNegative = "very_negative"
        case negative = "negative"
        case neutral = "neutral"
        case positive = "positive"
        case veryPositive = "very_positive"
    }
}

public struct UrgencyInsight: Codable, Sendable {
    public let level: UrgencyLevel
    public let deadline: Date?
    public let reasoning: String
    
    public enum UrgencyLevel: String, Codable, Sendable {
        case low
        case medium
        case high
        case critical
    }
}

public struct CategoryInsight: Codable, Sendable {
    public let primaryCategory: String
    public let subCategories: [String]
    public let confidence: Double
}

public struct ActionItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let description: String
    public let assignee: String?
    public let deadline: Date?
    public let priority: Priority
    
    public enum Priority: String, Codable, Sendable {
        case low
        case medium
        case high
    }
}

// MARK: - Analysis Configuration

/// Configuration for analysis operations
public struct AnalysisConfiguration: Codable, Sendable {
    public let types: [AnalysisType]
    public let language: String?
    public let customPrompts: [String: String]?
    public let timeout: TimeInterval
    public let maxTokens: Int?
    
    public init(
        types: [AnalysisType],
        language: String? = nil,
        customPrompts: [String: String]? = nil,
        timeout: TimeInterval = 30,
        maxTokens: Int? = nil
    ) {
        self.types = types
        self.language = language
        self.customPrompts = customPrompts
        self.timeout = timeout
        self.maxTokens = maxTokens
    }
}

// MARK: - Batch Analysis Request

public struct BatchAnalysisRequest: Sendable {
    public let emails: [Email]
    public let types: [AnalysisType]
    public let priority: BatchPriority
    
    public enum BatchPriority: Int, Sendable {
        case low = 0
        case normal = 1
        case high = 2
    }
    
    public init(emails: [Email], types: [AnalysisType], priority: BatchPriority = .normal) {
        self.emails = emails
        self.types = types
        self.priority = priority
    }
}

// MARK: - Analysis Progress

public struct AnalysisProgress: Sendable {
    public let totalEmails: Int
    public let processedEmails: Int
    public let currentEmailID: UUID?
    public let currentStage: String
    public let estimatedTimeRemaining: TimeInterval?
    
    public var progressPercentage: Double {
        guard totalEmails > 0 else { return 0 }
        return Double(processedEmails) / Double(totalEmails)
    }
}
