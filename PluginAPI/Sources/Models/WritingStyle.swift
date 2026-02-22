import Foundation

// MARK: - Writing Style

/// Represents a user's writing style characteristics
public struct WritingStyle: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String?
    
    // MARK: - Tone Characteristics
    
    public let tone: ToneCharacteristics
    
    // MARK: - Vocabulary
    
    public let vocabulary: VocabularyCharacteristics
    
    // MARK: - Structure
    
    public let structure: StructuralCharacteristics
    
    // MARK: - Formality
    
    public let formality: FormalityLevel
    
    // MARK: - Common Phrases
    
    public let commonOpenings: [String]
    public let commonClosings: [String]
    public let transitionPhrases: [String]
    
    // MARK: - Examples
    
    public let exampleEmails: [EmailExample]
    
    // MARK: - Metadata
    
    public let createdAt: Date
    public let updatedAt: Date
    public let sourceEmailsCount: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        tone: ToneCharacteristics,
        vocabulary: VocabularyCharacteristics,
        structure: StructuralCharacteristics,
        formality: FormalityLevel,
        commonOpenings: [String] = [],
        commonClosings: [String] = [],
        transitionPhrases: [String] = [],
        exampleEmails: [EmailExample] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceEmailsCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tone = tone
        self.vocabulary = vocabulary
        self.structure = structure
        self.formality = formality
        self.commonOpenings = commonOpenings
        self.commonClosings = commonClosings
        self.transitionPhrases = transitionPhrases
        self.exampleEmails = exampleEmails
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceEmailsCount = sourceEmailsCount
    }
}

// MARK: - Tone Characteristics

public struct ToneCharacteristics: Codable, Sendable {
    /// How friendly vs formal (0.0 = very formal, 1.0 = very friendly)
    public let friendliness: Double
    
    /// How direct vs indirect (0.0 = very indirect, 1.0 = very direct)
    public let directness: Double
    
    /// Level of enthusiasm (0.0 = reserved, 1.0 = very enthusiastic)
    public let enthusiasm: Double
    
    /// Use of humor (0.0 = serious, 1.0 = humorous)
    public let humor: Double
    
    /// Level of empathy expressed (0.0 = neutral, 1.0 = highly empathetic)
    public let empathy: Double
    
    /// Use of technical language (0.0 = simple, 1.0 = highly technical)
    public let technicality: Double
    
    public init(
        friendliness: Double,
        directness: Double,
        enthusiasm: Double = 0.5,
        humor: Double = 0.0,
        empathy: Double = 0.5,
        technicality: Double = 0.3
    ) {
        self.friendliness = max(0, min(1, friendliness))
        self.directness = max(0, min(1, directness))
        self.enthusiasm = max(0, min(1, enthusiasm))
        self.humor = max(0, min(1, humor))
        self.empathy = max(0, min(1, empathy))
        self.technicality = max(0, min(1, technicality))
    }
}

// MARK: - Vocabulary Characteristics

public struct VocabularyCharacteristics: Codable, Sendable {
    /// Complexity of vocabulary (0.0 = simple, 1.0 = complex)
    public let complexity: Double
    
    /// Use of industry jargon (0.0 = none, 1.0 = heavy)
    public let jargon: Double
    
    /// Use of contractions (0.0 = none, 1.0 = frequent)
    public let contractions: Double
    
    /// Average sentence length in words
    public let averageSentenceLength: Double
    
    /// Average word length in characters
    public let averageWordLength: Double
    
    /// Frequently used words
    public let frequentWords: [String]
    
    /// Words to avoid
    public let avoidedWords: [String]
    
    public init(
        complexity: Double = 0.5,
        jargon: Double = 0.3,
        contractions: Double = 0.5,
        averageSentenceLength: Double = 15,
        averageWordLength: Double = 4.5,
        frequentWords: [String] = [],
        avoidedWords: [String] = []
    ) {
        self.complexity = max(0, min(1, complexity))
        self.jargon = max(0, min(1, jargon))
        self.contractions = max(0, min(1, contractions))
        self.averageSentenceLength = averageSentenceLength
        self.averageWordLength = averageWordLength
        self.frequentWords = frequentWords
        self.avoidedWords = avoidedWords
    }
}

// MARK: - Structural Characteristics

public struct StructuralCharacteristics: Codable, Sendable {
    /// Average paragraph length in sentences
    public let averageParagraphLength: Double
    
    /// Use of bullet points and lists
    public let usesLists: Bool
    
    /// Use of greetings/signatures
    public let includesGreeting: Bool
    public let includesSignature: Bool
    
    /// Use of headers/sections
    public let usesHeaders: Bool
    
    /// Preferred greeting format
    public let greetingStyle: GreetingStyle
    
    /// Preferred signature format
    public let signatureStyle: SignatureStyle
    
    public init(
        averageParagraphLength: Double = 3,
        usesLists: Bool = true,
        includesGreeting: Bool = true,
        includesSignature: Bool = true,
        usesHeaders: Bool = false,
        greetingStyle: GreetingStyle = .nameOnly,
        signatureStyle: SignatureStyle = .nameOnly
    ) {
        self.averageParagraphLength = averageParagraphLength
        self.usesLists = usesLists
        self.includesGreeting = includesGreeting
        self.includesSignature = includesSignature
        self.usesHeaders = usesHeaders
        self.greetingStyle = greetingStyle
        self.signatureStyle = signatureStyle
    }
}

// MARK: - Greeting Style

public enum GreetingStyle: String, Codable, Sendable, CaseIterable {
    case none = "none"
    case nameOnly = "name_only"
    case hiName = "hi_name"
    case helloName = "hello_name"
    case dearName = "dear_name"
    case hiThere = "hi_there"
    case hello = "hello"
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = GreetingStyle(rawValue: rawValue) {
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
    
    public static var allCases: [GreetingStyle] {
        [.none, .nameOnly, .hiName, .helloName, .dearName, .hiThere, .hello]
    }
}

// MARK: - Signature Style

public enum SignatureStyle: String, Codable, Sendable, CaseIterable {
    case none = "none"
    case nameOnly = "name_only"
    case bestName = "best_name"
    case regardsName = "regards_name"
    case thanksName = "thanks_name"
    case cheersName = "cheers_name"
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = SignatureStyle(rawValue: rawValue) {
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
    
    public static var allCases: [SignatureStyle] {
        [.none, .nameOnly, .bestName, .regardsName, .thanksName, .cheersName]
    }
}

// MARK: - Formality Level

public enum FormalityLevel: String, Codable, Sendable, Comparable {
    case casual = "casual"
    case semiCasual = "semi_casual"
    case neutral = "neutral"
    case semiFormal = "semi_formal"
    case formal = "formal"
    
    public var numericValue: Int {
        switch self {
        case .casual: return 0
        case .semiCasual: return 1
        case .neutral: return 2
        case .semiFormal: return 3
        case .formal: return 4
        }
    }
    
    public static func < (lhs: FormalityLevel, rhs: FormalityLevel) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

// MARK: - Email Example

public struct EmailExample: Codable, Sendable, Identifiable {
    public let id: UUID
    public let subject: String
    public let body: String
    public let context: String?
    public let date: Date
    
    public init(
        id: UUID = UUID(),
        subject: String,
        body: String,
        context: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.subject = subject
        self.body = body
        self.context = context
        self.date = date
    }
}

// MARK: - Writing Profile

/// A collection of writing styles for different contexts
public struct WritingProfile: Codable, Sendable, Identifiable {
    public let id: UUID
    public let userID: String
    public let name: String
    public let isDefault: Bool
    
    /// Default style used when no specific match
    public let defaultStyle: WritingStyle
    
    /// Context-specific styles
    public let contextualStyles: [ContextualStyle]
    
    /// Contact-specific overrides
    public let contactStyles: [ContactStyleOverride]
    
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        userID: String,
        name: String,
        isDefault: Bool = false,
        defaultStyle: WritingStyle,
        contextualStyles: [ContextualStyle] = [],
        contactStyles: [ContactStyleOverride] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.isDefault = isDefault
        self.defaultStyle = defaultStyle
        self.contextualStyles = contextualStyles
        self.contactStyles = contactStyles
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Get the appropriate style for a given context
    public func style(for context: WritingContext, recipient: String? = nil) -> WritingStyle {
        // Check contact-specific override first
        if let recipient = recipient,
           let override = contactStyles.first(where: { $0.emailAddress == recipient }) {
            return override.style
        }
        
        // Check contextual style
        if let contextual = contextualStyles.first(where: { $0.applies(to: context) }) {
            return contextual.style
        }
        
        // Fall back to default
        return defaultStyle
    }
}

// MARK: - Writing Context

public struct WritingContext: Sendable {
    public let situation: WritingSituation
    public let relationship: RelationshipType
    public let urgency: UrgencyLevel
    public let topic: String?
    public let previousEmails: Int
    
    public init(
        situation: WritingSituation,
        relationship: RelationshipType,
        urgency: UrgencyLevel = .medium,
        topic: String? = nil,
        previousEmails: Int = 0
    ) {
        self.situation = situation
        self.relationship = relationship
        self.urgency = urgency
        self.topic = topic
        self.previousEmails = previousEmails
    }
}

// MARK: - Writing Situation

public enum WritingSituation: String, Codable, Sendable {
    case initialContact = "initial_contact"
    case followUp = "follow_up"
    case reply = "reply"
    case introduction = "introduction"
    case request = "request"
    case response = "response"
    case complaint = "complaint"
    case apology = "apology"
    case thankYou = "thank_you"
    case announcement = "announcement"
    case meetingScheduling = "meeting_scheduling"
    case question = "question"
}

// MARK: - Relationship Type

public enum RelationshipType: String, Codable, Sendable {
    case unknown = "unknown"
    case colleague = "colleague"
    case manager = "manager"
    case directReport = "direct_report"
    case client = "client"
    case vendor = "vendor"
    case partner = "partner"
    case friend = "friend"
    case family = "family"
    case acquaintance = "acquaintance"
}

// MARK: - Contextual Style

public struct ContextualStyle: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let style: WritingStyle
    public let situations: [WritingSituation]
    public let relationships: [RelationshipType]
    public let priority: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        style: WritingStyle,
        situations: [WritingSituation] = [],
        relationships: [RelationshipType] = [],
        priority: Int = 0
    ) {
        self.id = id
        self.name = name
        self.style = style
        self.situations = situations
        self.relationships = relationships
        self.priority = priority
    }
    
    public func applies(to context: WritingContext) -> Bool {
        let situationMatch = situations.isEmpty || situations.contains(context.situation)
        let relationshipMatch = relationships.isEmpty || relationships.contains(context.relationship)
        return situationMatch && relationshipMatch
    }
}

// MARK: - Contact Style Override

public struct ContactStyleOverride: Codable, Sendable, Identifiable {
    public let id: UUID
    public let emailAddress: String
    public let name: String?
    public let style: WritingStyle
    public let notes: String?
    
    public init(
        id: UUID = UUID(),
        emailAddress: String,
        name: String? = nil,
        style: WritingStyle,
        notes: String? = nil
    ) {
        self.id = id
        self.emailAddress = emailAddress
        self.name = name
        self.style = style
        self.notes = notes
    }
}

// MARK: - Urgency Level

public enum UrgencyLevel: String, Codable, Sendable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var numericValue: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
    
    public static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}
