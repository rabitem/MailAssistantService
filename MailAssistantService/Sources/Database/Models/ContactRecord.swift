import Foundation
import GRDB

/// GRDB Record for the contacts table
/// Stores enriched contact information
public struct ContactRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "contacts"
    
    // MARK: - Primary Key
    public var id: String
    
    // MARK: - Basic Info
    public var emailAddress: String
    public var displayName: String?
    public var firstName: String?
    public var lastName: String?
    public var company: String?
    public var title: String?
    public var phone: String?
    
    // MARK: - Notes & Metadata
    public var notes: String?
    
    // MARK: - Relationship Analysis
    /// Score from 0.0-1.0 indicating relationship strength
    public var relationshipScore: Double?
    
    /// Number of emails exchanged
    public var emailFrequency: Int
    
    /// Last contact date
    public var lastContactedAt: Date?
    
    // MARK: - Avatar/Photo
    public var avatarUrl: String?
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case emailAddress = "email_address"
        case displayName = "display_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case company
        case title
        case phone
        case notes
        case relationshipScore = "relationship_score"
        case emailFrequency = "email_frequency"
        case lastContactedAt = "last_contacted_at"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        emailAddress: String,
        displayName: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        company: String? = nil,
        title: String? = nil,
        phone: String? = nil,
        notes: String? = nil,
        avatarUrl: String? = nil
    ) {
        self.id = id
        self.emailAddress = emailAddress.lowercased()
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.title = title
        self.phone = phone
        self.notes = notes
        self.relationshipScore = nil
        self.emailFrequency = 0
        self.lastContactedAt = nil
        self.avatarUrl = avatarUrl
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Returns the full name if available, otherwise display name or email
    public var fullName: String {
        if let first = firstName, let last = lastName, !first.isEmpty || !last.isEmpty {
            return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        }
        return displayName ?? emailAddress
    }
    
    /// Returns initials for avatar placeholder
    public var initials: String {
        let components = fullName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
    
    /// Returns relationship strength description
    public var relationshipDescription: String {
        guard let score = relationshipScore else { return "Unknown" }
        switch score {
        case 0..<0.2: return "Very Low"
        case 0.2..<0.4: return "Low"
        case 0.4..<0.6: return "Medium"
        case 0.6..<0.8: return "Strong"
        case 0.8...1.0: return "Very Strong"
        default: return "Unknown"
        }
    }
    
    /// Returns frequency description based on email count
    public var frequencyDescription: String {
        switch emailFrequency {
        case 0: return "No emails"
        case 1...5: return "Occasional"
        case 6...20: return "Regular"
        case 21...50: return "Frequent"
        case 51...: return "Very Frequent"
        default: return "Unknown"
        }
    }
    
    // MARK: - PersistableRecord
    
    public func willInsert(_ db: Database) throws {
        var mutableSelf = self
        mutableSelf.createdAt = Date()
        mutableSelf.updatedAt = Date()
    }
    
    public func willUpdate(_ db: Database, columns: Set<String>) throws {
        var mutableSelf = self
        mutableSelf.updatedAt = Date()
    }
    
    // MARK: - Update Helpers
    
    /// Updates relationship metrics based on email interaction
    public mutating func recordInteraction(sentiment: Double = 0.5) {
        emailFrequency += 1
        lastContactedAt = Date()
        
        // Update relationship score using exponential moving average
        let alpha = 0.1 // Small weight for gradual changes
        let currentScore = relationshipScore ?? 0.5
        relationshipScore = currentScore * (1 - alpha) + sentiment * alpha
    }
    
    /// Merges data from another contact record
    public mutating func merge(with other: ContactRecord) {
        if displayName == nil || displayName!.isEmpty {
            displayName = other.displayName
        }
        if firstName == nil || firstName!.isEmpty {
            firstName = other.firstName
        }
        if lastName == nil || lastName!.isEmpty {
            lastName = other.lastName
        }
        if company == nil || company!.isEmpty {
            company = other.company
        }
        if title == nil || title!.isEmpty {
            title = other.title
        }
        if phone == nil || phone!.isEmpty {
            phone = other.phone
        }
        if notes == nil || notes!.isEmpty {
            notes = other.notes
        }
        if avatarUrl == nil || avatarUrl!.isEmpty {
            avatarUrl = other.avatarUrl
        }
        
        // Merge metrics
        emailFrequency += other.emailFrequency
        if let otherScore = other.relationshipScore {
            if let currentScore = relationshipScore {
                relationshipScore = (currentScore + otherScore) / 2
            } else {
                relationshipScore = otherScore
            }
        }
        
        // Use most recent contact date
        if let otherLast = other.lastContactedAt {
            if let currentLast = lastContactedAt {
                lastContactedAt = max(currentLast, otherLast)
            } else {
                lastContactedAt = otherLast
            }
        }
    }
}

// MARK: - Associations

extension ContactRecord {
    /// Association to emails sent by this contact
    public static let sentEmails = hasMany(EmailRecord.self, using: ForeignKey(["sender_contact_id"]))
    
    /// Association to writing profiles
    public static let writingProfiles = hasMany(WritingProfileRecord.self, using: ForeignKey(["contact_id"]))
}

// MARK: - Query Extensions

extension ContactRecord {
    /// Query by email address (case-insensitive)
    public static func withEmail(_ email: String) -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("email_address") == email.lowercased())
    }
    
    /// Search by name (first, last, or display)
    public static func search(byName query: String) -> QueryInterfaceRequest<ContactRecord> {
        let pattern = "%\(query)%"
        return filter(
            Column("first_name").like(pattern) ||
            Column("last_name").like(pattern) ||
            Column("display_name").like(pattern)
        )
    }
    
    /// Search by company
    public static func search(byCompany query: String) -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("company").like("%\(query)%"))
    }
    
    /// Query by relationship score range
    public static func withRelationshipScore(between min: Double, and max: Double) -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("relationship_score") >= min && Column("relationship_score") <= max)
    }
    
    /// Query for strong relationships
    public static func strongRelationships() -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("relationship_score") >= 0.6)
            .order(Column("relationship_score").desc)
    }
    
    /// Query for frequent contacts
    public static func frequentContacts(minEmails: Int = 10) -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("email_frequency") >= minEmails)
            .order(Column("email_frequency").desc)
    }
    
    /// Query for recently contacted
    public static func recentlyContacted(since date: Date) -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("last_contacted_at") >= date)
            .order(Column("last_contacted_at").desc)
    }
    
    /// Query for contacts needing attention (no recent contact)
    public static func needingAttention(since date: Date) -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("last_contacted_at") < date || Column("last_contacted_at") == nil)
            .order(Column("relationship_score").desc)
    }
    
    /// Query ordered by name
    public static func orderedByName() -> QueryInterfaceRequest<ContactRecord> {
        order(Column("last_name").asc, Column("first_name").asc)
    }
    
    /// Query ordered by relationship score
    public static func orderedByRelationship() -> QueryInterfaceRequest<ContactRecord> {
        order(Column("relationship_score").desc)
    }
    
    /// Query for contacts from a specific company
    public static func atCompany(_ company: String) -> QueryInterfaceRequest<ContactRecord> {
        filter(Column("company").like("%\(company)%"))
    }
}

// MARK: - Contact Import/Export

extension ContactRecord {
    /// Creates a vCard representation
    public func toVCard() -> String {
        var vcard = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "FN:\(fullName)",
            "EMAIL:\(emailAddress)"
        ]
        
        if let first = firstName {
            vcard.append("N:\(lastName ?? "");\(first);;;")
        }
        if let org = company {
            vcard.append("ORG:\(org)")
        }
        if let t = title {
            vcard.append("TITLE:\(t)")
        }
        if let tel = phone {
            vcard.append("TEL:\(tel)")
        }
        if let note = notes {
            vcard.append("NOTE:\(note)")
        }
        
        vcard.append("END:VCARD")
        return vcard.joined(separator: "\n")
    }
    
    /// Dictionary representation for export
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email_address": emailAddress,
            "email_frequency": emailFrequency,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]
        
        if let name = displayName { dict["display_name"] = name }
        if let first = firstName { dict["first_name"] = first }
        if let last = lastName { dict["last_name"] = last }
        if let comp = company { dict["company"] = comp }
        if let t = title { dict["title"] = t }
        if let tel = phone { dict["phone"] = tel }
        if let note = notes { dict["notes"] = note }
        if let score = relationshipScore { dict["relationship_score"] = score }
        if let lastContact = lastContactedAt { dict["last_contacted_at"] = ISO8601DateFormatter().string(from: lastContact) }
        if let avatar = avatarUrl { dict["avatar_url"] = avatar }
        
        return dict
    }
}
