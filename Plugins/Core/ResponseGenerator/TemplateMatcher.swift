import Foundation
import PluginAPI
import Shared

// MARK: - Template Matcher

/// Matches incoming emails to learned and predefined response templates
/// Suggests template-based responses for common email patterns
public actor TemplateMatcher {
    
    // MARK: - Properties
    
    private weak var plugin: ResponseGeneratorPlugin?
    private var logger: PluginLogger {
        plugin?.context.logger ?? PluginLoggerPlaceholder()
    }
    
    // MARK: - Templates
    
    private var systemTemplates: [ResponseTemplate] = []
    private var userTemplates: [ResponseTemplate] = []
    private var learnedPatterns: [LearnedPattern] = []
    
    // MARK: - Configuration
    
    private let similarityThreshold: Double = 0.75
    private let minTemplateConfidence: Double = 0.6
    
    // MARK: - Initialization
    
    init(plugin: ResponseGeneratorPlugin) {
        self.plugin = plugin
        loadSystemTemplates()
    }
    
    // MARK: - Public Methods
    
    /// Finds template matches for the given email
    func findMatches(
        for email: Email,
        context: GenerationContext
    ) async throws -> [ResponseSuggestion] {
        logger.info("Finding template matches for email: \(email.id)")
        
        var matches: [ResponseSuggestion] = []
        
        // Check system templates
        let systemMatches = await matchSystemTemplates(email: email, context: context)
        matches.append(contentsOf: systemMatches)
        
        // Check user templates
        let userMatches = await matchUserTemplates(email: email, context: context)
        matches.append(contentsOf: userMatches)
        
        // Check learned patterns
        let learnedMatches = await matchLearnedPatterns(email: email, context: context)
        matches.append(contentsOf: learnedMatches)
        
        // Sort by confidence and filter
        matches.sort { $0.confidence > $1.confidence }
        
        logger.info("Found \(matches.count) template matches")
        return matches
    }
    
    /// Adds a new user template
    func addUserTemplate(_ template: ResponseTemplate) async {
        userTemplates.append(template)
        logger.info("Added user template: \(template.name)")
    }
    
    /// Records a learned pattern from user behavior
    func recordLearnedPattern(
        incomingPattern: String,
        responseTemplate: String,
        context: EmailContext
    ) async {
        let pattern = LearnedPattern(
            id: UUID(),
            incomingPattern: incomingPattern,
            responseTemplate: responseTemplate,
            context: context,
            usageCount: 1,
            successRate: 1.0,
            createdAt: Date()
        )
        learnedPatterns.append(pattern)
        logger.debug("Recorded learned pattern: \(pattern.id)")
    }
    
    /// Gets quick reply templates for a specific context
    func getQuickReplies(for context: EmailContext) -> [QuickReplyTemplate] {
        return QuickReplyTemplates.all.filter { template in
            template.applies(to: context)
        }
    }
    
    /// Renders a template with variable substitution
    func renderTemplate(_ template: ResponseTemplate, with variables: [String: String]) -> String {
        var result = template.content
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
    
    // MARK: - Private Methods - System Templates
    
    private func matchSystemTemplates(
        email: Email,
        context: GenerationContext
    ) async -> [ResponseSuggestion] {
        var matches: [ResponseSuggestion] = []
        
        for template in systemTemplates {
            if let match = tryMatchTemplate(template, email: email, context: context) {
                matches.append(match)
            }
        }
        
        return matches
    }
    
    private func loadSystemTemplates() {
        systemTemplates = [
            // Acknowledgment templates
            ResponseTemplate(
                id: UUID(),
                name: "Quick Acknowledgment",
                category: .acknowledgment,
                content: "Hi {{senderName}},\n\nThanks for your email. I've received it and will get back to you shortly.\n\nBest,\n{{userName}}",
                variables: ["senderName", "userName"],
                isSystem: true
            ),
            
            // Meeting templates
            ResponseTemplate(
                id: UUID(),
                name: "Meeting Acceptance",
                category: .scheduling,
                content: "Hi {{senderName}},\n\nThanks for scheduling the meeting. I'm available at {{meetingTime}} and look forward to discussing {{topic}}.\n\nBest,\n{{userName}}",
                variables: ["senderName", "meetingTime", "topic", "userName"],
                isSystem: true
            ),
            
            ResponseTemplate(
                id: UUID(),
                name: "Meeting Decline with Alternative",
                category: .scheduling,
                content: "Hi {{senderName}},\n\nThank you for the meeting invitation. Unfortunately, I'm not available at {{proposedTime}}. Would {{alternativeTime}} work for you instead?\n\nBest,\n{{userName}}",
                variables: ["senderName", "proposedTime", "alternativeTime", "userName"],
                isSystem: true
            ),
            
            // Request templates
            ResponseTemplate(
                id: UUID(),
                name: "Request Received",
                category: .requestInfo,
                content: "Hi {{senderName}},\n\nThanks for your request. I'll need some time to gather the information you need. I'll get back to you by {{deadline}}.\n\nBest,\n{{userName}}",
                variables: ["senderName", "deadline", "userName"],
                isSystem: true
            ),
            
            // Follow-up templates
            ResponseTemplate(
                id: UUID(),
                name: "Follow-up Response",
                category: .followUp,
                content: "Hi {{senderName}},\n\nFollowing up on our previous conversation about {{topic}}. {{update}}\n\nPlease let me know if you have any questions.\n\nBest,\n{{userName}}",
                variables: ["senderName", "topic", "update", "userName"],
                isSystem: true
            ),
            
            // Thank you templates
            ResponseTemplate(
                id: UUID(),
                name: "Thank You Response",
                category: .thankYou,
                content: "Hi {{senderName}},\n\nThank you for {{reason}}. I really appreciate it!\n\nBest,\n{{userName}}",
                variables: ["senderName", "reason", "userName"],
                isSystem: true
            ),
            
            // Introduction templates
            ResponseTemplate(
                id: UUID(),
                name: "Introduction Response",
                category: .introduction,
                content: "Hi {{senderName}},\n\nNice to meet you! {{context}}\n\nLooking forward to working with you.\n\nBest,\n{{userName}}",
                variables: ["senderName", "context", "userName"],
                isSystem: true
            )
        ]
    }
    
    // MARK: - Private Methods - User Templates
    
    private func matchUserTemplates(
        email: Email,
        context: GenerationContext
    ) async -> [ResponseSuggestion] {
        // In actual implementation, would query from database
        // For now, return empty
        return []
    }
    
    // MARK: - Private Methods - Learned Patterns
    
    private func matchLearnedPatterns(
        email: Email,
        context: GenerationContext
    ) async -> [ResponseSuggestion] {
        let emailContent = (email.subject + " " + (email.bodyPlain ?? "")).lowercased()
        var matches: [ResponseSuggestion] = []
        
        for pattern in learnedPatterns {
            let similarity = calculateSimilarity(emailContent, pattern.incomingPattern)
            if similarity >= similarityThreshold {
                let suggestion = ResponseSuggestion(
                    id: UUID(),
                    emailID: email.id,
                    content: pattern.responseTemplate,
                    type: detectType(from: pattern),
                    confidence: pattern.reliabilityScore * similarity,
                    reasoning: "Based on your previous response (used \(pattern.usageCount) times, \(Int(similarity * 100))% similar)",
                    tone: .neutral,
                    source: ResponseGeneratorPlugin.pluginIdentifier + ".learned"
                )
                matches.append(suggestion)
            }
        }
        
        return matches
    }
    
    // MARK: - Private Methods - Template Matching
    
    private func tryMatchTemplate(
        _ template: ResponseTemplate,
        email: Email,
        context: GenerationContext
    ) -> ResponseSuggestion? {
        // Calculate match score based on category and content similarity
        let score = calculateTemplateMatchScore(template, email: email, context: context)
        
        guard score >= minTemplateConfidence else { return nil }
        
        // Extract variables for template
        let variables = extractVariables(for: template, email: email, context: context)
        let renderedContent = renderTemplate(template, with: variables)
        
        return ResponseSuggestion(
            id: UUID(),
            emailID: email.id,
            content: renderedContent,
            type: mapTemplateType(template.category),
            confidence: score,
            reasoning: "Template match: \(template.name) (\(Int(score * 100))% confidence)",
            tone: .professional,
            estimatedComposeTime: 30, // Quick to apply template
            source: ResponseGeneratorPlugin.pluginIdentifier + ".template",
            customizableFields: template.variables.map { varName in
                CustomizableField(
                    name: varName,
                    placeholder: "Enter \(varName)",
                    defaultValue: variables[varName] ?? "",
                    fieldType: .text,
                    isRequired: true
                )
            }
        )
    }
    
    private func calculateTemplateMatchScore(
        _ template: ResponseTemplate,
        email: Email,
        context: GenerationContext
    ) -> Double {
        var score = 0.5 // Base score
        
        let content = (email.subject + " " + (email.bodyPlain ?? "")).lowercased()
        
        // Check category relevance
        switch template.category {
        case .scheduling where context.detectedIntent == .scheduling:
            score += 0.3
        case .thankYou where content.contains("thank"):
            score += 0.3
        case .introduction where context.detectedIntent == .introduction:
            score += 0.3
        case .acknowledgment where content.contains("just checking"):
            score += 0.2
        default:
            break
        }
        
        // Check for specific keywords
        let keywords = templateKeywords(for: template)
        let keywordMatches = keywords.filter { content.contains($0) }.count
        score += Double(keywordMatches) * 0.05
        
        return min(0.95, score)
    }
    
    private func extractVariables(
        for template: ResponseTemplate,
        email: Email,
        context: GenerationContext
    ) -> [String: String] {
        var variables: [String: String] = [:]
        
        for variable in template.variables {
            switch variable {
            case "senderName":
                variables[variable] = email.from.name ?? email.from.address
            case "userName":
                variables[variable] = "[Your Name]" // Would be fetched from settings
            case "meetingTime":
                if let availability = context.calendarAvailability?.nextAvailableSlot {
                    variables[variable] = formatDate(availability)
                } else {
                    variables[variable] = "[Proposed Time]"
                }
            case "topic":
                variables[variable] = context.extractedTopics.first ?? "this topic"
            case "proposedTime":
                variables[variable] = "[Proposed Time]"
            case "alternativeTime":
                if let availability = context.calendarAvailability?.suggestedTimes.first {
                    variables[variable] = formatDate(availability)
                } else {
                    variables[variable] = "[Alternative Time]"
                }
            case "deadline":
                variables[variable] = formatDate(Date().addingTimeInterval(2 * 24 * 60 * 60))
            case "reason":
                variables[variable] = "your help"
            case "context":
                variables[variable] = "I've heard great things about your work."
            case "update":
                variables[variable] = "Here's the latest update:"
            default:
                variables[variable] = "[\(variable)]"
            }
        }
        
        return variables
    }
    
    private func templateKeywords(for template: ResponseTemplate) -> [String] {
        switch template.category {
        case .scheduling:
            return ["meet", "schedule", "time", "available", "calendar", "appointment"]
        case .thankYou:
            return ["thank", "appreciate", "grateful", "thanks"]
        case .introduction:
            return ["introduce", "introduction", "meet", "connected"]
        case .acknowledgment:
            return ["received", "noted", "acknowledge", "confirm"]
        case .decline:
            return ["unfortunately", "unable", "cannot", "decline", "busy"]
        default:
            return []
        }
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        // Simple similarity calculation based on common words
        // In production, this would use embeddings or more sophisticated algorithms
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }
    
    private func mapTemplateType(_ category: TemplateCategory) -> SuggestionType {
        switch category {
        case .acknowledgment: return .acknowledgment
        case .scheduling: return .scheduling
        case .requestInfo: return .requestInfo
        case .thankYou: return .thankYou
        case .introduction: return .detailed
        case .followUp: return .acknowledgment
        case .decline: return .decline
        case .accept: return .accept
        case .custom: return .custom("template")
        }
    }
    
    private func detectType(from pattern: LearnedPattern) -> SuggestionType {
        // Infer type from learned pattern
        let response = pattern.responseTemplate.lowercased()
        if response.contains("thank") { return .thankYou }
        if response.contains("meet") || response.contains("schedule") { return .scheduling }
        if response.contains("cannot") || response.contains("unfortunately") { return .decline }
        return .detailed
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Response Template

public struct ResponseTemplate: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let category: TemplateCategory
    public let content: String
    public let variables: [String]
    public let isSystem: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory,
        content: String,
        variables: [String],
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.content = content
        self.variables = variables
        self.isSystem = isSystem
    }
}

// MARK: - Template Category

public enum TemplateCategory: String, Sendable {
    case acknowledgment
    case scheduling
    case requestInfo
    case thankYou
    case introduction
    case followUp
    case decline
    case accept
    case custom
}

// MARK: - Learned Pattern

public struct LearnedPattern: Identifiable, Sendable {
    public let id: UUID
    public let incomingPattern: String
    public let responseTemplate: String
    public let context: EmailContext
    public var usageCount: Int
    public var successRate: Double
    public let createdAt: Date
    
    var reliabilityScore: Double {
        let usageWeight = min(Double(usageCount) / 10.0, 1.0)
        return (successRate ?? 0.5) * usageWeight
    }
}

// MARK: - Quick Reply Templates

public struct QuickReplyTemplates {
    public static let all: [QuickReplyTemplate] = [
        QuickReplyTemplate(
            name: "Yes, absolutely",
            content: "Yes, absolutely. I'll take care of that.",
            type: .accept,
            tone: .friendly,
            shortcut: "yes"
        ),
        QuickReplyTemplate(
            name: "Sounds good",
            content: "Sounds good to me. Thanks!",
            type: .accept,
            tone: .casual,
            shortcut: "sg"
        ),
        QuickReplyTemplate(
            name: "Thanks for the update",
            content: "Thanks for the update. I appreciate it.",
            type: .thankYou,
            tone: .friendly,
            shortcut: "ty"
        ),
        QuickReplyTemplate(
            name: "I'll get back to you",
            content: "I'll look into this and get back to you shortly.",
            type: .acknowledgment,
            tone: .professional,
            shortcut: "fyi"
        ),
        QuickReplyTemplate(
            name: "Confirmed",
            content: "Confirmed. I'll be there.",
            type: .accept,
            tone: .professional,
            shortcut: "cfm"
        )
    ]
}

public struct QuickReplyTemplate: Sendable {
    public let name: String
    public let content: String
    public let type: SuggestionType
    public let tone: SuggestionTone
    public let shortcut: String?
    
    func applies(to context: EmailContext) -> Bool {
        // Logic to determine if template applies to context
        return true
    }
}

public struct EmailContext: Sendable {
    public let subject: String?
    public let senderDomain: String?
    public let isReply: Bool
    public let threadLength: Int
}

// MARK: - Placeholder Logger

private struct PluginLoggerPlaceholder: PluginLogger {
    func debug(_ message: String) {}
    func info(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}
}
