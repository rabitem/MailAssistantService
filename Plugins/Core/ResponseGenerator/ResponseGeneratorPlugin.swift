import Foundation
import PluginAPI
import Shared

// MARK: - Response Generator Plugin

/// Core plugin that generates intelligent email response suggestions
/// Integrates with AI providers, RAG engine, and style learner
public final class ResponseGeneratorPlugin: NSObject, Plugin, EventSubscriber {
    
    // MARK: - Plugin Properties
    
    public static let pluginIdentifier = "core.response.generator"
    public static let displayName = "Response Generator"
    public static let version = "1.0.0"
    public static let description = "Generates contextual email response suggestions using AI and learned writing style"
    public static let pluginType: PluginType = .custom
    
    public static var requiredPermissions: [PluginPermission] {
        [
            .readEmails,
            .readThreads,
            .useAI,
            .networkAccess,
            .backgroundExecution,
            .pluginStorage,
            .accessWritingProfiles,
            .readContacts,
            .accessCalendar
        ]
    }
    
    public let subscriberID = "core.response.generator"
    
    public var subscribedEvents: [MailEventType] {
        [.composeStarted]
    }
    
    public let context: PluginContext
    
    // MARK: - Components
    
    private var suggestionEngine: SuggestionEngine!
    private var contextBuilder: ContextBuilder!
    private var templateMatcher: TemplateMatcher!
    
    // MARK: - State
    
    private var isActive = false
    private var generationTasks: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    public required init(context: PluginContext) async throws {
        self.context = context
        super.init()
        
        // Initialize components
        self.suggestionEngine = await SuggestionEngine(plugin: self)
        self.contextBuilder = await ContextBuilder(plugin: self)
        self.templateMatcher = await TemplateMatcher(plugin: self)
        
        context.logger.info("ResponseGeneratorPlugin initialized")
    }
    
    public func activate() async throws {
        guard !isActive else { return }
        
        // Subscribe to events
        await context.eventBus.subscribe(self)
        
        isActive = true
        context.logger.info("ResponseGeneratorPlugin activated")
    }
    
    public func deactivate() async throws {
        guard isActive else { return }
        
        // Cancel any pending generation tasks
        for (_, task) in generationTasks {
            task.cancel()
        }
        generationTasks.removeAll()
        
        // Unsubscribe from events
        await context.eventBus.unsubscribe(subscriberID)
        
        isActive = false
        context.logger.info("ResponseGeneratorPlugin deactivated")
    }
    
    public func updateConfiguration(_ configuration: [String: AnyCodable]) async throws {
        // Update configuration if needed
        context.logger.debug("ResponseGeneratorPlugin configuration updated")
    }
    
    // MARK: - Event Handling
    
    public func handleEvent(_ event: MailEvent) async {
        switch event {
        case .composeStarted(let draftID, let isReply, let originalEmailID):
            await handleComposeStarted(
                draftID: draftID,
                isReply: isReply,
                originalEmailID: originalEmailID
            )
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func handleComposeStarted(
        draftID: UUID,
        isReply: Bool,
        originalEmailID: UUID?
    ) async {
        guard isActive, let emailID = originalEmailID else { return }
        
        context.logger.info("Handling composeStarted for email: \(emailID)")
        
        // Cancel any existing task for this draft
        generationTasks[draftID]?.cancel()
        
        // Start new generation task
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
                // Generate suggestions
                let suggestions = try await generateSuggestions(for: emailID)
                
                // Check for cancellation again
                try Task.checkCancellation()
                
                // Publish suggestions event
                await publishSuggestions(emailID: emailID, suggestions: suggestions)
                
            } catch is CancellationError {
                context.logger.debug("Generation cancelled for draft: \(draftID)")
            } catch {
                context.logger.error("Failed to generate suggestions: \(error.localizedDescription)")
                await publishGenerationError(emailID: emailID, error: error)
            }
            
            // Remove task from tracking
            self.generationTasks.removeValue(forKey: draftID)
        }
        
        generationTasks[draftID] = task
    }
    
    private func generateSuggestions(for emailID: UUID) async throws -> [ResponseSuggestion] {
        // Build comprehensive context
        let generationContext = try await contextBuilder.buildContext(for: emailID)
        
        // Check for template matches first
        let templateSuggestions = try await templateMatcher.findMatches(
            for: generationContext.email,
            context: generationContext
        )
        
        // Generate AI-powered suggestions
        let aiSuggestions = try await suggestionEngine.generateSuggestions(
            context: generationContext,
            count: 3
        )
        
        // Combine and rank suggestions
        var allSuggestions = templateSuggestions + aiSuggestions
        
        // Sort by confidence
        allSuggestions.sort { $0.confidence > $1.confidence }
        
        // Return top suggestions (max 5)
        return Array(allSuggestions.prefix(5))
    }
    
    private func publishSuggestions(emailID: UUID, suggestions: [ResponseSuggestion]) async {
        let event = MailEvent.responseSuggestionsGenerated(
            emailID: emailID,
            suggestions: suggestions
        )
        await context.eventBus.publish(event)
        
        context.logger.info("Published \(suggestions.count) suggestions for email: \(emailID)")
    }
    
    private func publishGenerationError(emailID: UUID, error: Error) async {
        let event = MailEvent.aiGenerationFailed(
            requestID: emailID,
            error: error.localizedDescription
        )
        await context.eventBus.publish(event)
    }
}

// MARK: - Generation Context

/// Context passed through the response generation pipeline
public struct GenerationContext: Sendable {
    public let email: Email
    public let threadHistory: [Email]
    public let sender: Contact?
    public let writingStyle: WritingStyle?
    public let ragExamples: [RAGExample]
    public let calendarAvailability: CalendarAvailability?
    public let extractedTopics: [String]
    public let detectedIntent: EmailIntent
    
    public init(
        email: Email,
        threadHistory: [Email] = [],
        sender: Contact? = nil,
        writingStyle: WritingStyle? = nil,
        ragExamples: [RAGExample] = [],
        calendarAvailability: CalendarAvailability? = nil,
        extractedTopics: [String] = [],
        detectedIntent: EmailIntent = .reply
    ) {
        self.email = email
        self.threadHistory = threadHistory
        self.sender = sender
        self.writingStyle = writingStyle
        self.ragExamples = ragExamples
        self.calendarAvailability = calendarAvailability
        self.extractedTopics = extractedTopics
        self.detectedIntent = detectedIntent
    }
}

// MARK: - Supporting Types

public struct CalendarAvailability: Sendable {
    public let hasConflicts: Bool
    public let nextAvailableSlot: Date?
    public let suggestedTimes: [Date]
    
    public init(
        hasConflicts: Bool = false,
        nextAvailableSlot: Date? = nil,
        suggestedTimes: [Date] = []
    ) {
        self.hasConflicts = hasConflicts
        self.nextAvailableSlot = nextAvailableSlot
        self.suggestedTimes = suggestedTimes
    }
}

public enum EmailIntent: String, Sendable {
    case reply
    case followUp
    case introduction
    case scheduling
    case request
    case decline
    case accept
    case question
    case announcement
    case thankYou
}
