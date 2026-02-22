import Foundation

// MARK: - Contact

public struct Contact: Identifiable, Codable, Sendable {
    public let id: String
    public let email: String
    public let name: String?
    
    // Interaction stats
    public let emailCountReceived: Int
    public let emailCountSent: Int
    public let lastContacted: Date?
    public let firstContacted: Date?
    
    // Relationship strength (calculated)
    public let relationshipScore: Double?
    
    // AI-enriched data
    public let company: String?
    public let role: String?
    public let topics: [String]
    
    // Timestamps
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        email: String,
        name: String? = nil,
        emailCountReceived: Int = 0,
        emailCountSent: Int = 0,
        lastContacted: Date? = nil,
        firstContacted: Date? = nil,
        relationshipScore: Double? = nil,
        company: String? = nil,
        role: String? = nil,
        topics: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.emailCountReceived = emailCountReceived
        self.emailCountSent = emailCountSent
        self.lastContacted = lastContacted
        self.firstContacted = firstContacted
        self.relationshipScore = relationshipScore
        self.company = company
        self.role = role
        self.topics = topics
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Relationship Info

public struct RelationshipInfo: Sendable {
    public let contact: Contact
    public let interactionFrequency: InteractionFrequency
    public let commonTopics: [String]
    public let lastInteractions: [Email]
    public let suggestedTone: String
    
    public init(
        contact: Contact,
        interactionFrequency: InteractionFrequency,
        commonTopics: [String],
        lastInteractions: [Email],
        suggestedTone: String
    ) {
        self.contact = contact
        self.interactionFrequency = interactionFrequency
        self.commonTopics = commonTopics
        self.lastInteractions = lastInteractions
        self.suggestedTone = suggestedTone
    }
}

public enum InteractionFrequency: String, Sendable {
    case daily
    case weekly
    case monthly
    case occasionally
    case rare
    case new
}
