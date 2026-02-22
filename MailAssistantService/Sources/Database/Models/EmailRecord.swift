import Foundation
import GRDB

/// GRDB Record for the emails table
public struct EmailRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "emails"
    
    // MARK: - Primary Key
    public var id: String
    
    // MARK: - Message Identity
    public var messageId: String
    public var threadId: String?
    public var accountId: String
    
    // MARK: - Folder & Location
    public var folder: String
    
    // MARK: - Content
    public var subject: String?
    public var bodyText: String?
    public var bodyHtml: String?
    
    // MARK: - Sender/Recipients
    public var fromAddress: String
    public var fromName: String?
    public var toAddresses: String // JSON array
    public var ccAddresses: String? // JSON array
    public var bccAddresses: String? // JSON array
    public var senderContactId: String?
    
    // MARK: - Timestamps
    public var sentAt: Date?
    public var receivedAt: Date
    
    // MARK: - Flags
    public var isRead: Bool
    public var isFlagged: Bool
    public var isArchived: Bool
    public var isDraft: Bool
    
    // MARK: - AI Processing
    public var priority: Int?
    public var summary: String?
    public var actionItems: String? // JSON array
    public var category: String?
    public var sentiment: String?
    public var urgencyScore: Double?
    
    // MARK: - Processing Status
    public var processedAt: Date?
    public var processingStatus: ProcessingStatus
    public var errorMessage: String?
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Enums
    
    public enum ProcessingStatus: String, Codable, DatabaseValueConvertible {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
        case skipped = "skipped"
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case threadId = "thread_id"
        case accountId = "account_id"
        case folder
        case subject
        case bodyText = "body_text"
        case bodyHtml = "body_html"
        case fromAddress = "from_address"
        case fromName = "from_name"
        case toAddresses = "to_addresses"
        case ccAddresses = "cc_addresses"
        case bccAddresses = "bcc_addresses"
        case senderContactId = "sender_contact_id"
        case sentAt = "sent_at"
        case receivedAt = "received_at"
        case isRead = "is_read"
        case isFlagged = "is_flagged"
        case isArchived = "is_archived"
        case isDraft = "is_draft"
        case priority
        case summary
        case actionItems = "action_items"
        case category
        case sentiment
        case urgencyScore = "urgency_score"
        case processedAt = "processed_at"
        case processingStatus = "processing_status"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        messageId: String,
        threadId: String? = nil,
        accountId: String,
        folder: String = "INBOX",
        subject: String? = nil,
        bodyText: String? = nil,
        bodyHtml: String? = nil,
        fromAddress: String,
        fromName: String? = nil,
        toAddresses: [String] = [],
        ccAddresses: [String] = [],
        bccAddresses: [String] = [],
        senderContactId: String? = nil,
        sentAt: Date? = nil,
        receivedAt: Date,
        isRead: Bool = false,
        isFlagged: Bool = false,
        isArchived: Bool = false,
        isDraft: Bool = false,
        priority: Int? = nil,
        summary: String? = nil,
        actionItems: [String] = [],
        category: String? = nil,
        sentiment: String? = nil,
        urgencyScore: Double? = nil,
        processingStatus: ProcessingStatus = .pending
    ) {
        self.id = id
        self.messageId = messageId
        self.threadId = threadId
        self.accountId = accountId
        self.folder = folder
        self.subject = subject
        self.bodyText = bodyText
        self.bodyHtml = bodyHtml
        self.fromAddress = fromAddress
        self.fromName = fromName
        self.toAddresses = (try? JSONEncoder().encode(toAddresses))?.utf8String ?? "[]"
        self.ccAddresses = (try? JSONEncoder().encode(ccAddresses))?.utf8String ?? "[]"
        self.bccAddresses = (try? JSONEncoder().encode(bccAddresses))?.utf8String ?? "[]"
        self.senderContactId = senderContactId
        self.sentAt = sentAt
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.isArchived = isArchived
        self.isDraft = isDraft
        self.priority = priority
        self.summary = summary
        self.actionItems = (try? JSONEncoder().encode(actionItems))?.utf8String ?? "[]"
        self.category = category
        self.sentiment = sentiment
        self.urgencyScore = urgencyScore
        self.processingStatus = processingStatus
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - PersistableRecord
    
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        // Row inserted successfully, timestamps already set in init
    }
    
    // MARK: - JSON Helpers
    
    public func getToAddresses() -> [String] {
        guard let data = toAddresses.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    public func getCcAddresses() -> [String] {
        guard let addresses = ccAddresses,
              let data = addresses.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    public func getBccAddresses() -> [String] {
        guard let addresses = bccAddresses,
              let data = addresses.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    public func getActionItems() -> [String] {
        guard let items = actionItems,
              let data = items.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - Associations

extension EmailRecord {
    /// Association to thread
    public static let thread = belongsTo(ThreadRecord.self, using: ForeignKey(["thread_id"]))
    
    /// Association to sender contact
    public static let sender = belongsTo(ContactRecord.self, using: ForeignKey(["sender_contact_id"]))
    
    /// Association to metadata
    public static let metadata = hasMany(EmailMetadataRecord.self, using: ForeignKey(["email_id"]))
    
    /// Association to embedding
    public static let embedding = hasOne(EmailEmbeddingRecord.self, using: ForeignKey(["email_id"]))
}

// MARK: - Query Extensions

extension EmailRecord {
    /// Query for unread emails
    public static func unread() -> QueryInterfaceRequest<EmailRecord> {
        filter(Column("is_read") == false)
    }
    
    /// Query for emails in a folder
    public static func inFolder(_ folder: String) -> QueryInterfaceRequest<EmailRecord> {
        filter(Column("folder") == folder)
    }
    
    /// Query for emails by account
    public static func forAccount(_ accountId: String) -> QueryInterfaceRequest<EmailRecord> {
        filter(Column("account_id") == accountId)
    }
    
    /// Query for emails with pending processing
    public static func pendingProcessing() -> QueryInterfaceRequest<EmailRecord> {
        filter(Column("processing_status") == ProcessingStatus.pending.rawValue)
    }
    
    /// Query for emails by category
    public static func withCategory(_ category: String) -> QueryInterfaceRequest<EmailRecord> {
        filter(Column("category") == category)
    }
    
    /// Query for emails in a date range
    public static func inDateRange(from: Date, to: Date) -> QueryInterfaceRequest<EmailRecord> {
        filter(Column("received_at") >= from && Column("received_at") <= to)
    }
    
    /// Query for important emails (flagged or high priority)
    public static func important() -> QueryInterfaceRequest<EmailRecord> {
        filter(Column("is_flagged") == true || Column("priority") >= 3)
            .order(Column("received_at").desc)
    }
    
    /// Full-text search query
    public static func matchingFTS(_ query: String) -> QueryInterfaceRequest<EmailRecord> {
        // Join with FTS table
        let pattern = FTS5Pattern(matchingAllPrefixesIn: query) ?? FTS5Pattern(matchingPhrase: query)
        return filter(sql: "emails.rowid IN (SELECT rowid FROM emails_fts WHERE emails_fts MATCH ?)",
                     arguments: [pattern.rawDescription])
    }
}

// MARK: - Data Extension

private extension Data {
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}

// MARK: - Thread Record

public struct ThreadRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "threads"
    
    public var id: String
    public var subject: String?
    public var participants: String // JSON array
    public var messageCount: Int
    public var lastMessageAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case participants
        case messageCount = "message_count"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public var emails: QueryInterfaceRequest<EmailRecord> {
        request(for: ThreadRecord.emails)
    }
    
    public static let emails = hasMany(EmailRecord.self, using: ForeignKey(["thread_id"]))
}

// MARK: - Email Metadata Record

public struct EmailMetadataRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "email_metadata"
    
    public var id: Int64?
    public var emailId: String
    public var pluginId: String?
    public var key: String
    public var value: String?
    public var valueType: ValueType
    public var createdAt: Date
    public var updatedAt: Date
    
    public enum ValueType: String, Codable, DatabaseValueConvertible {
        case string = "string"
        case number = "number"
        case boolean = "boolean"
        case json = "json"
        case date = "date"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case emailId = "email_id"
        case pluginId = "plugin_id"
        case key
        case value
        case valueType = "value_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// MARK: - Email Embedding Record

public struct EmailEmbeddingRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "email_embeddings"
    
    public var id: Int64?
    public var emailId: String
    public var embedding: Data
    public var modelName: String
    public var dimensions: Int
    public var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case emailId = "email_id"
        case embedding
        case modelName = "model_name"
        case dimensions
        case createdAt = "created_at"
    }
    
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
