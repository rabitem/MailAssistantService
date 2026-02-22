import Foundation

// MARK: - Response Suggestion

/// Represents a suggested response to an email
public struct ResponseSuggestion: Codable, Sendable, Identifiable {
    public let id: UUID
    
    /// The email this suggestion is for
    public let emailID: UUID
    
    /// The suggested response text
    public let content: String
    
    /// Type of suggestion
    public let type: SuggestionType
    
    /// Confidence score (0.0 - 1.0)
    public let confidence: Double
    
    /// Reasoning for why this suggestion is appropriate
    public let reasoning: String?
    
    /// Tone of the suggestion
    public let tone: SuggestionTone
    
    /// Estimated time to compose manually
    public let estimatedComposeTime: TimeInterval?
    
    /// When the suggestion was generated
    public let generatedAt: Date
    
    /// ID of the plugin/generator that created this
    public let source: String
    
    /// Action items addressed by this response
    public let addressedActionItems: [ActionItem]
    
    /// Questions answered by this response
    public let answeredQuestions: [String]
    
    /// Whether this suggestion has been used
    public let isUsed: Bool
    
    /// User feedback on this suggestion
    public let userRating: SuggestionRating?
    
    /// Alternative variations of this suggestion
    public let variations: [SuggestionVariation]
    
    /// Customization options
    public let customizableFields: [CustomizableField]
    
    public init(
        id: UUID = UUID(),
        emailID: UUID,
        content: String,
        type: SuggestionType,
        confidence: Double,
        reasoning: String? = nil,
        tone: SuggestionTone,
        estimatedComposeTime: TimeInterval? = nil,
        generatedAt: Date = Date(),
        source: String,
        addressedActionItems: [ActionItem] = [],
        answeredQuestions: [String] = [],
        isUsed: Bool = false,
        userRating: SuggestionRating? = nil,
        variations: [SuggestionVariation] = [],
        customizableFields: [CustomizableField] = []
    ) {
        self.id = id
        self.emailID = emailID
        self.content = content
        self.type = type
        self.confidence = confidence
        self.reasoning = reasoning
        self.tone = tone
        self.estimatedComposeTime = estimatedComposeTime
        self.generatedAt = generatedAt
        self.source = source
        self.addressedActionItems = addressedActionItems
        self.answeredQuestions = answeredQuestions
        self.isUsed = isUsed
        self.userRating = userRating
        self.variations = variations
        self.customizableFields = customizableFields
    }
}

// MARK: - Suggestion Type

public enum SuggestionType: String, Codable, Sendable, CaseIterable {
    /// A quick acknowledgment
    case acknowledgment = "acknowledgment"
    
    /// A detailed response
    case detailed = "detailed"
    
    /// A brief response
    case brief = "brief"
    
    /// A follow-up question
    case question = "question"
    
    /// A thank you response
    case thankYou = "thank_you"
    
    /// A declination/refusal
    case decline = "decline"
    
    /// An acceptance
    case accept = "accept"
    
    /// Scheduling-related
    case scheduling = "scheduling"
    
    /// Forwarding to someone else
    case forward = "forward"
    
    /// Request for more information
    case requestInfo = "request_info"
    
    /// Apology
    case apology = "apology"
    
    /// Congratulations
    case congratulations = "congratulations"
    
    /// Custom suggestion type
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = SuggestionType(rawValue: rawValue) {
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
    
    public static var allCases: [SuggestionType] {
        [
            .acknowledgment, .detailed, .brief, .question, .thankYou,
            .decline, .accept, .scheduling, .forward, .requestInfo,
            .apology, .congratulations
        ]
    }
    
    public var displayName: String {
        switch self {
        case .acknowledgment: return "Acknowledgment"
        case .detailed: return "Detailed Response"
        case .brief: return "Brief Response"
        case .question: return "Question"
        case .thankYou: return "Thank You"
        case .decline: return "Decline"
        case .accept: return "Accept"
        case .scheduling: return "Scheduling"
        case .forward: return "Forward"
        case .requestInfo: return "Request Information"
        case .apology: return "Apology"
        case .congratulations: return "Congratulations"
        case .custom(let value): return value.capitalized
        }
    }
}

// MARK: - Suggestion Tone

public enum SuggestionTone: String, Codable, Sendable, CaseIterable {
    case professional = "professional"
    case casual = "casual"
    case friendly = "friendly"
    case formal = "formal"
    case empathetic = "empathetic"
    case assertive = "assertive"
    case diplomatic = "diplomatic"
    case enthusiastic = "enthusiastic"
    case neutral = "neutral"
    case urgent = "urgent"
    
    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Suggestion Rating

public struct SuggestionRating: Codable, Sendable {
    public let rating: Rating
    public let feedback: String?
    public let ratedAt: Date
    
    public init(rating: Rating, feedback: String? = nil, ratedAt: Date = Date()) {
        self.rating = rating
        self.feedback = feedback
        self.ratedAt = ratedAt
    }
}

// MARK: - Rating

public enum Rating: String, Codable, Sendable {
    case thumbsUp = "thumbs_up"
    case thumbsDown = "thumbs_down"
    case neutral = "neutral"
    
    public var isPositive: Bool {
        self == .thumbsUp
    }
}

// MARK: - Suggestion Variation

public struct SuggestionVariation: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let content: String
    public let description: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        content: String,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.description = description
    }
}

// MARK: - Customizable Field

public struct CustomizableField: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let placeholder: String
    public let defaultValue: String
    public let fieldType: FieldType
    public let isRequired: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        placeholder: String,
        defaultValue: String = "",
        fieldType: FieldType = .text,
        isRequired: Bool = false
    ) {
        self.id = id
        self.name = name
        self.placeholder = placeholder
        self.defaultValue = defaultValue
        self.fieldType = fieldType
        self.isRequired = isRequired
    }
}

// MARK: - Field Type

public enum FieldType: String, Codable, Sendable {
    case text
    case number
    case date
    case time
    case dateTime = "datetime"
    case email
    case url
    case selection
    case multiline
}

// MARK: - Suggestion Request

/// Request parameters for generating response suggestions
public struct SuggestionRequest: Sendable {
    public let emailID: UUID
    public let context: SuggestionContext
    public let preferences: SuggestionPreferences
    public let count: Int
    
    public init(
        emailID: UUID,
        context: SuggestionContext = SuggestionContext(),
        preferences: SuggestionPreferences = SuggestionPreferences(),
        count: Int = 3
    ) {
        self.emailID = emailID
        self.context = context
        self.preferences = preferences
        self.count = count
    }
}

// MARK: - Suggestion Context

public struct SuggestionContext: Sendable {
    public let threadHistory: [Email]?
    public let userIntent: UserIntent?
    public let previousSuggestions: [ResponseSuggestion]?
    public let externalContext: [String: AnyCodable]
    
    public init(
        threadHistory: [Email]? = nil,
        userIntent: UserIntent? = nil,
        previousSuggestions: [ResponseSuggestion]? = nil,
        externalContext: [String: AnyCodable] = [:]
    ) {
        self.threadHistory = threadHistory
        self.userIntent = userIntent
        self.previousSuggestions = previousSuggestions
        self.externalContext = externalContext
    }
}

// MARK: - User Intent

public enum UserIntent: String, Codable, Sendable {
    case reply = "reply"
    case forward = "forward"
    case archive = "archive"
    case delete = "delete"
    case scheduleMeeting = "schedule_meeting"
    case requestInfo = "request_info"
    case delegate = "delegate"
    case followUp = "follow_up"
    case noAction = "no_action"
}

// MARK: - Suggestion Preferences

public struct SuggestionPreferences: Sendable {
    public let preferredTypes: [SuggestionType]
    public let preferredTone: SuggestionTone?
    public let maxLength: Int?
    public let includeGreeting: Bool
    public let includeSignature: Bool
    public let writingProfileID: UUID?
    
    public init(
        preferredTypes: [SuggestionType] = [],
        preferredTone: SuggestionTone? = nil,
        maxLength: Int? = nil,
        includeGreeting: Bool = true,
        includeSignature: Bool = true,
        writingProfileID: UUID? = nil
    ) {
        self.preferredTypes = preferredTypes
        self.preferredTone = preferredTone
        self.maxLength = maxLength
        self.includeGreeting = includeGreeting
        self.includeSignature = includeSignature
        self.writingProfileID = writingProfileID
    }
}

// MARK: - Suggestion Batch

/// A batch of suggestions for multiple emails
public struct SuggestionBatch: Codable, Sendable, Identifiable {
    public let id: UUID
    public let emailID: UUID
    public let suggestions: [ResponseSuggestion]
    public let generatedAt: Date
    public let expiresAt: Date?
    
    public var hasHighConfidenceSuggestion: Bool {
        suggestions.contains { $0.confidence > 0.8 }
    }
    
    public var bestSuggestion: ResponseSuggestion? {
        suggestions.max { $0.confidence < $1.confidence }
    }
    
    public init(
        id: UUID = UUID(),
        emailID: UUID,
        suggestions: [ResponseSuggestion],
        generatedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.emailID = emailID
        self.suggestions = suggestions
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - Suggestion Statistics

/// Statistics about suggestion usage
public struct SuggestionStatistics: Codable, Sendable {
    public let totalGenerated: Int
    public let totalUsed: Int
    public let totalDismissed: Int
    public let averageConfidence: Double
    public let averageRating: Double?
    public let byType: [String: TypeStatistics]
    public let byTone: [String: Int]
    
    public var usageRate: Double {
        guard totalGenerated > 0 else { return 0 }
        return Double(totalUsed) / Double(totalGenerated)
    }
    
    public init(
        totalGenerated: Int,
        totalUsed: Int,
        totalDismissed: Int,
        averageConfidence: Double,
        averageRating: Double? = nil,
        byType: [String: TypeStatistics] = [:],
        byTone: [String: Int] = [:]
    ) {
        self.totalGenerated = totalGenerated
        self.totalUsed = totalUsed
        self.totalDismissed = totalDismissed
        self.averageConfidence = averageConfidence
        self.averageRating = averageRating
        self.byType = byType
        self.byTone = byTone
    }
}

// MARK: - Type Statistics

public struct TypeStatistics: Codable, Sendable {
    public let generated: Int
    public let used: Int
    public let averageConfidence: Double
    
    public var usageRate: Double {
        guard generated > 0 else { return 0 }
        return Double(used) / Double(generated)
    }
    
    public init(generated: Int, used: Int, averageConfidence: Double) {
        self.generated = generated
        self.used = used
        self.averageConfidence = averageConfidence
    }
}

// MARK: - Quick Reply Template

/// Pre-defined quick reply templates
public struct QuickReplyTemplate: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let content: String
    public let type: SuggestionType
    public let tone: SuggestionTone
    public let isSystem: Bool
    public let shortcut: String?
    public let usageCount: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        content: String,
        type: SuggestionType,
        tone: SuggestionTone,
        isSystem: Bool = false,
        shortcut: String? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.type = type
        self.tone = tone
        self.isSystem = isSystem
        self.shortcut = shortcut
        self.usageCount = usageCount
    }
}
