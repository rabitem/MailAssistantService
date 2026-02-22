import Foundation
import PluginAPI
import Shared

// MARK: - Context Builder

/// Builds comprehensive context for response generation by gathering
/// email thread history, sender information, writing style, and calendar data
public actor ContextBuilder {
    
    // MARK: - Properties
    
    private weak var plugin: ResponseGeneratorPlugin?
    private var logger: PluginLogger {
        plugin?.context.logger ?? PluginLoggerPlaceholder()
    }
    
    // MARK: - Caching
    
    private var emailCache: [UUID: Email] = [:]
    private var contactCache: [String: Contact] = [:]
    private var styleCache: [UUID: WritingStyle] = [:]
    private var threadCache: [UUID: [Email]] = [:]
    
    // MARK: - Initialization
    
    init(plugin: ResponseGeneratorPlugin) {
        self.plugin = plugin
    }
    
    // MARK: - Public Methods
    
    /// Builds a complete generation context for the given email
    func buildContext(for emailID: UUID) async throws -> GenerationContext {
        logger.info("Building context for email: \(emailID)")
        
        // Fetch the email
        let email = try await fetchEmail(id: emailID)
        
        // Build context components concurrently
        async let threadHistory = fetchThreadHistory(for: email)
        async let sender = fetchSender(for: email)
        async let writingStyle = fetchWritingStyle(for: email)
        async let ragExamples = fetchRAGExamples(for: email)
        async let calendarAvailability = fetchCalendarAvailability(for: email)
        async let (topics, intent) = analyzeContent(of: email)
        
        // Wait for all components
        let context = GenerationContext(
            email: email,
            threadHistory: await threadHistory,
            sender: await sender,
            writingStyle: await writingStyle,
            ragExamples: await ragExamples,
            calendarAvailability: await calendarAvailability,
            extractedTopics: await topics,
            detectedIntent: await intent
        )
        
        logger.info("Context built: \(context.threadHistory.count) thread emails, \(context.ragExamples.count) RAG examples")
        
        return context
    }
    
    /// Clears all caches
    func clearCache() {
        emailCache.removeAll()
        contactCache.removeAll()
        styleCache.removeAll()
        threadCache.removeAll()
        logger.debug("Context caches cleared")
    }
    
    // MARK: - Private Methods - Email Fetching
    
    private func fetchEmail(id: UUID) async throws -> Email {
        if let cached = emailCache[id] {
            return cached
        }
        
        // In actual implementation, this would query the database
        // For now, we throw an error as placeholder
        throw ContextBuilderError.emailNotFound(id: id)
    }
    
    // MARK: - Private Methods - Thread History
    
    private func fetchThreadHistory(for email: Email) async -> [Email] {
        guard let threadID = email.threadID else {
            return []
        }
        
        if let cached = threadCache[threadID] {
            return cached
        }
        
        // In actual implementation, query database for thread emails
        // For now, return empty array
        return []
    }
    
    // MARK: - Private Methods - Sender Info
    
    private func fetchSender(for email: Email) async -> Contact? {
        let senderEmail = email.from.address
        
        if let cached = contactCache[senderEmail] {
            return cached
        }
        
        // In actual implementation, query contacts database
        // For now, return nil
        return nil
    }
    
    // MARK: - Private Methods - Writing Style
    
    private func fetchWritingStyle(for email: Email) async -> WritingStyle? {
        // Determine appropriate writing style based on:
        // 1. Sender relationship
        // 2. Email context (work, personal, etc.)
        // 3. User's default style profile
        
        // In actual implementation, query writing style profiles
        // For now, return nil
        return nil
    }
    
    // MARK: - Private Methods - RAG Examples
    
    private func fetchRAGExamples(for email: Email) async -> [RAGExample] {
        // In actual implementation, call RAGEngine
        // For now, return empty array
        // Example: try? await RAGEngine.shared.getRAGExamples(for: email)
        return []
    }
    
    // MARK: - Private Methods - Calendar
    
    private func fetchCalendarAvailability(for email: Email) async -> CalendarAvailability? {
        // Only fetch calendar data if email is scheduling-related
        guard isSchedulingRelated(email: email) else {
            return nil
        }
        
        // In actual implementation, query calendar integration
        // For now, return default availability
        return CalendarAvailability(
            hasConflicts: false,
            nextAvailableSlot: Date().addingTimeInterval(24 * 60 * 60), // Tomorrow
            suggestedTimes: [
                Date().addingTimeInterval(24 * 60 * 60),
                Date().addingTimeInterval(2 * 24 * 60 * 60),
                Date().addingTimeInterval(3 * 24 * 60 * 60)
            ]
        )
    }
    
    private func isSchedulingRelated(email: Email) -> Bool {
        let content = (email.subject + " " + (email.bodyPlain ?? "")).lowercased()
        let schedulingKeywords = [
            "meet", "meeting", "schedule", "appointment", "call",
            "available", "free", "time", "calendar", "booking",
            "when", "what time", "suggest a time", "let's meet"
        ]
        return schedulingKeywords.contains { content.contains($0) }
    }
    
    // MARK: - Private Methods - Content Analysis
    
    private func analyzeContent(of email: Email) async -> ([String], EmailIntent) {
        let content = email.subject + " " + (email.bodyPlain ?? "")
        
        // Extract topics
        let topics = extractTopics(from: content)
        
        // Detect intent
        let intent = detectIntent(from: email, content: content)
        
        return (topics, intent)
    }
    
    private func extractTopics(from content: String) -> [String] {
        var topics: [String] = []
        let lowercased = content.lowercased()
        
        // Simple keyword-based topic extraction
        let topicKeywords: [String: [String]] = [
            "meeting": ["meeting", "discuss", "call", "sync", "review"],
            "deadline": ["deadline", "due date", "by friday", "by monday", "by tomorrow"],
            "project": ["project", "deliverable", "milestone", "phase"],
            "budget": ["budget", "cost", "price", "quote", "invoice", "payment"],
            "feedback": ["feedback", "thoughts", "opinion", "review"],
            "introduction": ["introduce", "introduction", "connect", "meet each other"],
            "follow-up": ["follow up", "following up", "circling back", "checking in"]
        ]
        
        for (topic, keywords) in topicKeywords {
            if keywords.contains(where: { lowercased.contains($0) }) {
                topics.append(topic)
            }
        }
        
        return topics
    }
    
    private func detectIntent(from email: Email, content: String) -> EmailIntent {
        let lowercased = content.lowercased()
        let subject = email.subject.lowercased()
        
        // Check for explicit keywords
        if lowercased.contains("introduce") || lowercased.contains("introduction") {
            return .introduction
        }
        
        if lowercased.contains("following up") || lowercased.contains("follow up") || lowercased.contains("circling back") {
            return .followUp
        }
        
        if isSchedulingRelated(email: email) {
            return .scheduling
        }
        
        if lowercased.contains("thank") || subject.hasPrefix("re: thank") {
            return .thankYou
        }
        
        if lowercased.contains("?") || lowercased.contains("could you") || lowercased.contains("would you") {
            return .question
        }
        
        if lowercased.contains("request") || lowercased.contains("need you to") || lowercased.contains("please") {
            return .request
        }
        
        if lowercased.contains("unfortunately") || lowercased.contains("unable") || lowercased.contains("cannot") || lowercased.contains("decline") {
            return .decline
        }
        
        if lowercased.contains("accept") || lowercased.contains("happy to") || lowercased.contains("glad to") {
            return .accept
        }
        
        if lowercased.contains("announce") || lowercased.contains("introducing") || lowercased.contains("we're launching") {
            return .announcement
        }
        
        // Default to reply
        return .reply
    }
    
    // MARK: - Private Methods - Cache Management
    
    private func cacheEmail(_ email: Email) {
        emailCache[email.id] = email
    }
    
    private func cacheContact(_ contact: Contact) {
        contactCache[contact.email] = contact
    }
    
    private func cacheThread(id: UUID, emails: [Email]) {
        threadCache[id] = emails
    }
}

// MARK: - Errors

enum ContextBuilderError: Error, LocalizedError {
    case emailNotFound(id: UUID)
    case databaseError(underlying: Error)
    case invalidThread(id: UUID)
    
    var errorDescription: String? {
        switch self {
        case .emailNotFound(let id):
            return "Email not found: \(id)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .invalidThread(let id):
            return "Invalid thread: \(id)"
        }
    }
}

// MARK: - Contact Model Extension

private extension Contact {
    var relationshipScore: Double? {
        // Calculate relationship strength based on email frequency
        // This is a simplified version - actual implementation would be more sophisticated
        guard emailCountReceived + emailCountSent > 0 else { return nil }
        let totalEmails = Double(emailCountReceived + emailCountSent)
        return min(1.0, totalEmails / 20.0) // Max score at 20 emails
    }
}

// MARK: - Placeholder Logger

private struct PluginLoggerPlaceholder: PluginLogger {
    func debug(_ message: String) {}
    func info(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}
}
