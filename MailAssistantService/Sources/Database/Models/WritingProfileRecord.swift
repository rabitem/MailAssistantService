import Foundation
import GRDB

/// GRDB Record for the writing_profiles table
/// Stores analyzed writing style profiles for contacts
public struct WritingProfileRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "writing_profiles"
    
    // MARK: - Primary Key
    public var id: String
    
    // MARK: - Relationships
    public var contactId: String
    public var name: String
    
    // MARK: - Style Analysis
    
    /// Formality level from 0.0 (casual) to 1.0 (formal)
    public var formalityLevel: Double?
    
    /// Average sentence length in words
    public var avgSentenceLength: Double?
    
    /// Frequently used phrases (JSON array)
    public var commonPhrases: String?
    
    /// Vocabulary fingerprint/signature (JSON object with word frequencies)
    public var vocabularyFingerprint: String?
    
    /// Punctuation style description
    public var punctuationStyle: String?
    
    /// Preferred greeting style
    public var greetingStyle: String?
    
    /// Preferred closing/sign-off style
    public var closingStyle: String?
    
    /// Emoji usage frequency (0.0-1.0)
    public var emojiUsage: Double?
    
    // MARK: - Behavioral Analysis
    
    /// Average response time in hours
    public var responseTimeAvg: Double?
    
    /// Detected timezone
    public var timezone: String?
    
    // MARK: - Statistics
    
    /// When the profile was last analyzed
    public var lastAnalyzedAt: Date?
    
    /// Number of samples used for analysis
    public var sampleCount: Int
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case name
        case formalityLevel = "formality_level"
        case avgSentenceLength = "avg_sentence_length"
        case commonPhrases = "common_phrases"
        case vocabularyFingerprint = "vocabulary_fingerprint"
        case punctuationStyle = "punctuation_style"
        case greetingStyle = "greeting_style"
        case closingStyle = "closing_style"
        case emojiUsage = "emoji_usage"
        case responseTimeAvg = "response_time_avg"
        case timezone
        case lastAnalyzedAt = "last_analyzed_at"
        case sampleCount = "sample_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        contactId: String,
        name: String,
        formalityLevel: Double? = nil,
        avgSentenceLength: Double? = nil,
        commonPhrases: [String] = [],
        vocabularyFingerprint: [String: Double]? = nil,
        punctuationStyle: String? = nil,
        greetingStyle: String? = nil,
        closingStyle: String? = nil,
        emojiUsage: Double? = nil,
        responseTimeAvg: Double? = nil,
        timezone: String? = nil,
        sampleCount: Int = 0
    ) {
        self.id = id
        self.contactId = contactId
        self.name = name
        self.formalityLevel = formalityLevel
        self.avgSentenceLength = avgSentenceLength
        self.commonPhrases = (try? JSONEncoder().encode(commonPhrases))?.utf8String
        self.vocabularyFingerprint = vocabularyFingerprint.flatMap { try? JSONEncoder().encode($0) }?.utf8String
        self.punctuationStyle = punctuationStyle
        self.greetingStyle = greetingStyle
        self.closingStyle = closingStyle
        self.emojiUsage = emojiUsage
        self.responseTimeAvg = responseTimeAvg
        self.timezone = timezone
        self.sampleCount = sampleCount
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - PersistableRecord
    
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        // Row inserted successfully, timestamps already set in init
    }
    
    // MARK: - JSON Helpers
    
    public func getCommonPhrases() -> [String] {
        guard let phrases = commonPhrases,
              let data = phrases.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    public func getVocabularyFingerprint() -> [String: Double] {
        guard let fingerprint = vocabularyFingerprint,
              let data = fingerprint.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
    
    // MARK: - Style Analysis Helpers
    
    /// Returns a description of the formality level
    public var formalityDescription: String {
        guard let level = formalityLevel else { return "Unknown" }
        switch level {
        case 0..<0.2: return "Very Casual"
        case 0.2..<0.4: return "Casual"
        case 0.4..<0.6: return "Neutral"
        case 0.6..<0.8: return "Formal"
        case 0.8...1.0: return "Very Formal"
        default: return "Unknown"
        }
    }
    
    /// Returns a description of emoji usage
    public var emojiUsageDescription: String {
        guard let usage = emojiUsage else { return "Unknown" }
        switch usage {
        case 0: return "Never"
        case 0..<0.1: return "Rarely"
        case 0.1..<0.3: return "Occasionally"
        case 0.3..<0.6: return "Frequently"
        case 0.6...: return "Very Frequently"
        default: return "Unknown"
        }
    }
    
    /// Generates a writing style summary
    public func styleSummary() -> String {
        var components: [String] = []
        
        components.append("Formality: \(formalityDescription)")
        
        if let greeting = greetingStyle {
            components.append("Greeting: \(greeting)")
        }
        
        if let closing = closingStyle {
            components.append("Closing: \(closing)")
        }
        
        components.append("Emoji usage: \(emojiUsageDescription)")
        
        if let avgLength = avgSentenceLength {
            components.append("Avg sentence: \(String(format: "%.1f", avgLength)) words")
        }
        
        return components.joined(separator: " | ")
    }
}

// MARK: - Associations

extension WritingProfileRecord {
    /// Association to contact
    public static let contact = belongsTo(ContactRecord.self, using: ForeignKey(["contact_id"]))
}

// MARK: - Query Extensions

extension WritingProfileRecord {
    /// Query for profiles by contact
    public static func forContact(_ contactId: String) -> QueryInterfaceRequest<WritingProfileRecord> {
        filter(Column("contact_id") == contactId)
    }
    
    /// Query for profiles by name
    public static func withName(_ name: String) -> QueryInterfaceRequest<WritingProfileRecord> {
        filter(Column("name") == name)
    }
    
    /// Query for contact's profile by name
    public static func forContact(_ contactId: String, name: String) -> QueryInterfaceRequest<WritingProfileRecord> {
        filter(Column("contact_id") == contactId && Column("name") == name)
    }
    
    /// Query for profiles with minimum sample count
    public static func withMinSamples(_ count: Int) -> QueryInterfaceRequest<WritingProfileRecord> {
        filter(Column("sample_count") >= count)
    }
    
    /// Query for profiles by formality level range
    public static func withFormality(between min: Double, and max: Double) -> QueryInterfaceRequest<WritingProfileRecord> {
        filter(Column("formality_level") >= min && Column("formality_level") <= max)
    }
    
    /// Query for profiles that need re-analysis (older than given date)
    public static func needsAnalysis(since date: Date) -> QueryInterfaceRequest<WritingProfileRecord> {
        filter(Column("last_analyzed_at") == nil || Column("last_analyzed_at") < date)
    }
    
    /// Query ordered by most recently analyzed
    public static func recentlyAnalyzed() -> QueryInterfaceRequest<WritingProfileRecord> {
        order(Column("last_analyzed_at").desc)
    }
    
    /// Query ordered by sample count (most analyzed first)
    public static func mostReliable() -> QueryInterfaceRequest<WritingProfileRecord> {
        order(Column("sample_count").desc)
    }
}

// MARK: - Data Extension

private extension Data {
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}
