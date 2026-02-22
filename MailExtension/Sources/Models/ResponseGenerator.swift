//
//  ResponseGenerator.swift
//  MailExtension
//

import Foundation
import MailKit

/// Represents a generated response suggestion
struct GeneratedResponse: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let tone: ResponseTone
    let length: ResponseLength
    let confidence: Double
    let timestamp: Date
    
    init(id: UUID = UUID(), 
         text: String, 
         tone: ResponseTone, 
         length: ResponseLength, 
         confidence: Double = 1.0) {
        self.id = id
        self.text = text
        self.tone = tone
        self.length = length
        self.confidence = confidence
        self.timestamp = Date()
    }
}

/// Tone options for generated responses
enum ResponseTone: String, Codable, CaseIterable, Identifiable {
    case formal = "formal"
    case casual = "casual"
    case friendly = "friendly"
    case professional = "professional"
    case empathetic = "empathetic"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .formal: return "Formal"
        case .casual: return "Casual"
        case .friendly: return "Friendly"
        case .professional: return "Professional"
        case .empathetic: return "Empathetic"
        }
    }
    
    var icon: String {
        switch self {
        case .formal: return "doc.text"
        case .casual: return "bubble"
        case .friendly: return "hand.wave"
        case .professional: return "briefcase"
        case .empathetic: return "heart"
        }
    }
    
    var description: String {
        switch self {
        case .formal: return "Polite and structured"
        case .casual: return "Relaxed and conversational"
        case .friendly: return "Warm and approachable"
        case .professional: return "Business-appropriate"
        case .empathetic: return "Understanding and supportive"
        }
    }
}

/// Length options for generated responses
enum ResponseLength: String, Codable, CaseIterable, Identifiable {
    case brief = "brief"
    case standard = "standard"
    case detailed = "detailed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .brief: return "Brief"
        case .standard: return "Standard"
        case .detailed: return "Detailed"
        }
    }
    
    var description: String {
        switch self {
        case .brief: return "Quick and to the point"
        case .standard: return "Balanced response"
        case .detailed: return "Comprehensive reply"
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .brief: return 150
        case .standard: return 300
        case .detailed: return 600
        }
    }
}

/// Style profile for consistent response generation
struct StyleProfile: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let tone: ResponseTone
    let length: ResponseLength
    let customInstructions: String?
    let isDefault: Bool
    
    init(id: UUID = UUID(),
         name: String,
         tone: ResponseTone,
         length: ResponseLength,
         customInstructions: String? = nil,
         isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.tone = tone
        self.length = length
        self.customInstructions = customInstructions
        self.isDefault = isDefault
    }
    
    static let `default` = StyleProfile(
        name: "Default",
        tone: .professional,
        length: .standard,
        isDefault: true
    )
    
    static let quick = StyleProfile(
        name: "Quick Reply",
        tone: .casual,
        length: .brief,
        isDefault: false
    )
    
    static let formal = StyleProfile(
        name: "Formal Business",
        tone: .formal,
        length: .standard,
        isDefault: false
    )
}

/// Generation state for tracking async operations
enum GenerationState: Equatable {
    case idle
    case analyzing
    case generating(progress: Double)
    case completed([GeneratedResponse])
    case error(String)
    
    static func == (lhs: GenerationState, rhs: GenerationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.analyzing, .analyzing): return true
        case let (.generating(p1), .generating(p2)): return p1 == p2
        case let (.completed(r1), .completed(r2)): return r1.count == r2.count
        case let (.error(e1), .error(e2)): return e1 == e2
        default: return false
        }
    }
    
    var isLoading: Bool {
        switch self {
        case .analyzing, .generating: return true
        default: return false
        }
    }
    
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
    
    var hasError: Bool {
        if case .error = self { return true }
        return false
    }
}

/// Request model for response generation
struct GenerationRequest: Codable {
    let emailContent: EmailContent
    let tone: ResponseTone
    let length: ResponseLength
    let styleProfile: StyleProfile?
    let previousResponses: [String]?
    let context: GenerationContext
    
    struct GenerationContext: Codable {
        let isReply: Bool
        let isForward: Bool
        let threadCount: Int
        let urgencyIndicators: [String]
        let actionItems: [String]
    }
}

/// Email content model
struct EmailContent: Codable {
    let subject: String
    let body: String
    let sender: String
    let recipients: [String]
    let threadMessages: [ThreadMessage]?
    let attachments: [AttachmentInfo]?
    
    struct ThreadMessage: Codable {
        let sender: String
        let body: String
        let timestamp: Date
        let isIncoming: Bool
    }
    
    struct AttachmentInfo: Codable {
        let filename: String
        let mimeType: String
        let size: Int
    }
}

/// Response variants for multiple suggestions
struct ResponseVariant: Identifiable, Equatable {
    let id: UUID
    let response: GeneratedResponse
    let preview: String
    let isExpanded: Bool
    
    init(id: UUID = UUID(), 
         response: GeneratedResponse, 
         preview: String? = nil,
         isExpanded: Bool = false) {
        self.id = id
        self.response = response
        self.preview = preview ?? String(response.text.prefix(150))
        self.isExpanded = isExpanded
    }
}
