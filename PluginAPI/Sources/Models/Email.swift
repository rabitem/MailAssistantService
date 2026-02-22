import Foundation

// MARK: - Email Model

/// Represents an email message in the system
public struct Email: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let messageID: String
    public let threadID: UUID?
    
    // MARK: - Headers
    
    public let subject: String
    public let from: EmailAddress
    public let to: [EmailAddress]
    public let cc: [EmailAddress]
    public let bcc: [EmailAddress]
    public let replyTo: EmailAddress?
    public let sender: EmailAddress?
    
    // MARK: - Content
    
    public let bodyPlain: String?
    public let bodyHTML: String?
    public let preview: String
    
    // MARK: - Timestamps
    
    public let date: Date
    public let receivedAt: Date
    public let modifiedAt: Date
    
    // MARK: - Status
    
    public let isRead: Bool
    public let isFlagged: Bool
    public let isDraft: Bool
    public let importance: EmailImportance
    
    // MARK: - Organization
    
    public let folder: String
    public let labels: [String]
    public let categories: [EmailCategory]
    
    // MARK: - Attachments
    
    public let attachments: [EmailAttachment]
    
    // MARK: - Metadata
    
    public let inReplyTo: String?
    public let references: [String]
    public let headers: [String: String]
    public let source: EmailSource
    
    // MARK: - Analysis Results
    
    public let analysisResults: [AnalysisResult]?
    
    public init(
        id: UUID = UUID(),
        messageID: String,
        threadID: UUID? = nil,
        subject: String,
        from: EmailAddress,
        to: [EmailAddress],
        cc: [EmailAddress] = [],
        bcc: [EmailAddress] = [],
        replyTo: EmailAddress? = nil,
        sender: EmailAddress? = nil,
        bodyPlain: String? = nil,
        bodyHTML: String? = nil,
        preview: String = "",
        date: Date,
        receivedAt: Date? = nil,
        modifiedAt: Date? = nil,
        isRead: Bool = false,
        isFlagged: Bool = false,
        isDraft: Bool = false,
        importance: EmailImportance = .normal,
        folder: String = "INBOX",
        labels: [String] = [],
        categories: [EmailCategory] = [],
        attachments: [EmailAttachment] = [],
        inReplyTo: String? = nil,
        references: [String] = [],
        headers: [String: String] = [:],
        source: EmailSource,
        analysisResults: [AnalysisResult]? = nil
    ) {
        self.id = id
        self.messageID = messageID
        self.threadID = threadID
        self.subject = subject
        self.from = from
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.replyTo = replyTo
        self.sender = sender
        self.bodyPlain = bodyPlain
        self.bodyHTML = bodyHTML
        self.preview = preview
        self.date = date
        self.receivedAt = receivedAt ?? date
        self.modifiedAt = modifiedAt ?? date
        self.isRead = isRead
        self.isFlagged = isFlagged
        self.isDraft = isDraft
        self.importance = importance
        self.folder = folder
        self.labels = labels
        self.categories = categories
        self.attachments = attachments
        self.inReplyTo = inReplyTo
        self.references = references
        self.headers = headers
        self.source = source
        self.analysisResults = analysisResults
    }
}

// MARK: - Email Address

public struct EmailAddress: Codable, Sendable, Hashable, CustomStringConvertible {
    public let address: String
    public let name: String?
    
    public var displayName: String {
        name ?? address
    }
    
    public var description: String {
        if let name = name {
            return "\(name) <\(address)>"
        }
        return address
    }
    
    public init(address: String, name: String? = nil) {
        self.address = address.lowercased()
        self.name = name
    }
    
    public init?(raw: String) {
        // Parse "Name <email@example.com>" or "email@example.com"
        let pattern = #"(?:"?([^"<>]+)"?\s*)?<([^<>\s]+)>|([^<>\s]+)"#
        // Simplified parsing - in production use proper regex
        if raw.contains("<") && raw.contains(">") {
            let parts = raw.split(separator: "<")
            if parts.count == 2 {
                let name = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let addr = String(parts[1]).replacingOccurrences(of: ">", with: "")
                self.name = name.isEmpty ? nil : name
                self.address = addr.lowercased()
                return
            }
        }
        self.name = nil
        self.address = raw.lowercased()
    }
}

// MARK: - Email Importance

public enum EmailImportance: String, Codable, Sendable, Comparable {
    case low
    case normal
    case high
    
    public var priority: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        }
    }
    
    public static func < (lhs: EmailImportance, rhs: EmailImportance) -> Bool {
        lhs.priority < rhs.priority
    }
}

// MARK: - Email Category

public enum EmailCategory: String, Codable, Sendable, CaseIterable {
    case primary = "primary"
    case social = "social"
    case promotions = "promotions"
    case updates = "updates"
    case forums = "forums"
    case spam = "spam"
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = EmailCategory(rawValue: rawValue) {
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
    
    public static var allCases: [EmailCategory] {
        [.primary, .social, .promotions, .updates, .forums, .spam]
    }
}

// MARK: - Email Attachment

public struct EmailAttachment: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let filename: String
    public let mimeType: String
    public let size: Int
    public let contentID: String?
    public let isInline: Bool
    public let downloadURL: String?
    public let checksum: String?
    
    public var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    public init(
        id: String = UUID().uuidString,
        filename: String,
        mimeType: String,
        size: Int,
        contentID: String? = nil,
        isInline: Bool = false,
        downloadURL: String? = nil,
        checksum: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentID = contentID
        self.isInline = isInline
        self.downloadURL = downloadURL
        self.checksum = checksum
    }
}

// MARK: - Email Source

public struct EmailSource: Codable, Sendable, Hashable {
    public let accountID: String
    public let provider: EmailProvider
    public let mailbox: String
    public let protocolVersion: String?
    
    public init(
        accountID: String,
        provider: EmailProvider,
        mailbox: String = "INBOX",
        protocolVersion: String? = nil
    ) {
        self.accountID = accountID
        self.provider = provider
        self.mailbox = mailbox
        self.protocolVersion = protocolVersion
    }
}

// MARK: - Email Provider

public enum EmailProvider: String, Codable, Sendable {
    case gmail = "gmail"
    case outlook = "outlook"
    case yahoo = "yahoo"
    case icloud = "icloud"
    case protonmail = "protonmail"
    case exchange = "exchange"
    case imap = "imap"
    case pop3 = "pop3"
    case other = "other"
}

// MARK: - Email Builder

/// Builder pattern for creating emails
public struct EmailBuilder {
    private var email: Email
    
    public init(source: EmailSource) {
        email = Email(
            messageID: UUID().uuidString,
            subject: "",
            from: EmailAddress(address: ""),
            to: [],
            date: Date(),
            source: source
        )
    }
    
    public func subject(_ subject: String) -> Self {
        var copy = self
        copy.email = Email(
            id: email.id,
            messageID: email.messageID,
            threadID: email.threadID,
            subject: subject,
            from: email.from,
            to: email.to,
            cc: email.cc,
            bcc: email.bcc,
            replyTo: email.replyTo,
            sender: email.sender,
            bodyPlain: email.bodyPlain,
            bodyHTML: email.bodyHTML,
            preview: email.preview,
            date: email.date,
            receivedAt: email.receivedAt,
            modifiedAt: email.modifiedAt,
            isRead: email.isRead,
            isFlagged: email.isFlagged,
            isDraft: email.isDraft,
            importance: email.importance,
            folder: email.folder,
            labels: email.labels,
            categories: email.categories,
            attachments: email.attachments,
            inReplyTo: email.inReplyTo,
            references: email.references,
            headers: email.headers,
            source: email.source,
            analysisResults: email.analysisResults
        )
        return copy
    }
    
    public func from(_ address: EmailAddress) -> Self {
        var copy = self
        copy.email = Email(
            id: email.id,
            messageID: email.messageID,
            threadID: email.threadID,
            subject: email.subject,
            from: address,
            to: email.to,
            cc: email.cc,
            bcc: email.bcc,
            replyTo: email.replyTo,
            sender: email.sender,
            bodyPlain: email.bodyPlain,
            bodyHTML: email.bodyHTML,
            preview: email.preview,
            date: email.date,
            receivedAt: email.receivedAt,
            modifiedAt: email.modifiedAt,
            isRead: email.isRead,
            isFlagged: email.isFlagged,
            isDraft: email.isDraft,
            importance: email.importance,
            folder: email.folder,
            labels: email.labels,
            categories: email.categories,
            attachments: email.attachments,
            inReplyTo: email.inReplyTo,
            references: email.references,
            headers: email.headers,
            source: email.source,
            analysisResults: email.analysisResults
        )
        return copy
    }
    
    public func to(_ addresses: [EmailAddress]) -> Self {
        var copy = self
        copy.email = Email(
            id: email.id,
            messageID: email.messageID,
            threadID: email.threadID,
            subject: email.subject,
            from: email.from,
            to: addresses,
            cc: email.cc,
            bcc: email.bcc,
            replyTo: email.replyTo,
            sender: email.sender,
            bodyPlain: email.bodyPlain,
            bodyHTML: email.bodyHTML,
            preview: email.preview,
            date: email.date,
            receivedAt: email.receivedAt,
            modifiedAt: email.modifiedAt,
            isRead: email.isRead,
            isFlagged: email.isFlagged,
            isDraft: email.isDraft,
            importance: email.importance,
            folder: email.folder,
            labels: email.labels,
            categories: email.categories,
            attachments: email.attachments,
            inReplyTo: email.inReplyTo,
            references: email.references,
            headers: email.headers,
            source: email.source,
            analysisResults: email.analysisResults
        )
        return copy
    }
    
    public func body(plain: String?, html: String? = nil) -> Self {
        var copy = self
        let preview = plain?.prefix(200).description ?? ""
        copy.email = Email(
            id: email.id,
            messageID: email.messageID,
            threadID: email.threadID,
            subject: email.subject,
            from: email.from,
            to: email.to,
            cc: email.cc,
            bcc: email.bcc,
            replyTo: email.replyTo,
            sender: email.sender,
            bodyPlain: plain,
            bodyHTML: html,
            preview: preview,
            date: email.date,
            receivedAt: email.receivedAt,
            modifiedAt: email.modifiedAt,
            isRead: email.isRead,
            isFlagged: email.isFlagged,
            isDraft: email.isDraft,
            importance: email.importance,
            folder: email.folder,
            labels: email.labels,
            categories: email.categories,
            attachments: email.attachments,
            inReplyTo: email.inReplyTo,
            references: email.references,
            headers: email.headers,
            source: email.source,
            analysisResults: email.analysisResults
        )
        return copy
    }
    
    public func build() -> Email {
        email
    }
}

// MARK: - Email Thread Summary

public struct EmailThreadSummary: Codable, Sendable, Identifiable {
    public let id: UUID
    public let subject: String
    public let participants: [EmailAddress]
    public let messageCount: Int
    public let unreadCount: Int
    public let lastMessageDate: Date
    public let preview: String
    public let hasAttachments: Bool
    public let isFlagged: Bool
    
    public init(
        id: UUID = UUID(),
        subject: String,
        participants: [EmailAddress],
        messageCount: Int,
        unreadCount: Int,
        lastMessageDate: Date,
        preview: String,
        hasAttachments: Bool,
        isFlagged: Bool
    ) {
        self.id = id
        self.subject = subject
        self.participants = participants
        self.messageCount = messageCount
        self.unreadCount = unreadCount
        self.lastMessageDate = lastMessageDate
        self.preview = preview
        self.hasAttachments = hasAttachments
        self.isFlagged = isFlagged
    }
}
