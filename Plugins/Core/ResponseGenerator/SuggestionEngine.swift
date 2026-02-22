import Foundation
import PluginAPI
import Shared

// MARK: - Suggestion Engine

/// Generates contextual email response suggestions using AI providers
public actor SuggestionEngine {
    
    // MARK: - Properties
    
    private weak var plugin: ResponseGeneratorPlugin?
    private var logger: PluginLogger {
        plugin?.context.logger ?? PluginLoggerPlaceholder()
    }
    
    // MARK: - Configuration
    
    private var configuration: SuggestionConfiguration = .default
    
    // MARK: - Initialization
    
    init(plugin: ResponseGeneratorPlugin) {
        self.plugin = plugin
    }
    
    // MARK: - Public Methods
    
    /// Generates multiple response suggestions with different tones
    func generateSuggestions(
        context: GenerationContext,
        count: Int = 3
    ) async throws -> [ResponseSuggestion] {
        logger.info("Generating \(count) suggestions for email: \(context.email.id)")
        
        var suggestions: [ResponseSuggestion] = []
        
        // Generate variants with different tones
        let variants = generateVariants(count: count)
        
        for (index, variant) in variants.enumerated() {
            do {
                let suggestion = try await generateVariant(
                    context: context,
                    variant: variant,
                    index: index
                )
                suggestions.append(suggestion)
            } catch {
                logger.error("Failed to generate variant \(variant.name): \(error.localizedDescription)")
            }
        }
        
        logger.info("Successfully generated \(suggestions.count) suggestions")
        return suggestions
    }
    
    /// Generates a single response using AI provider
    func generateSingleResponse(
        context: GenerationContext,
        tone: ResponseTone,
        length: ResponseLength
    ) async throws -> String {
        let prompt = buildPrompt(context: context, tone: tone, length: length)
        let systemPrompt = buildSystemPrompt(context: context)
        
        // Access AI Provider Manager through plugin context
        // Note: In actual implementation, this would be injected or accessed via a protocol
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            context: buildEmailContext(from: context),
            style: context.writingStyle,
            temperature: 0.7,
            maxTokens: length.maxTokens
        )
        
        // This would call the actual AI provider
        // For now, we return a placeholder that would be implemented
        // with the actual AIProviderManager integration
        return try await generateWithAI(request: request)
    }
    
    // MARK: - Private Methods
    
    private func generateVariants(count: Int) -> [VariantConfig] {
        let allVariants: [VariantConfig] = [
            VariantConfig(name: "Professional", tone: .professional, length: .medium, type: .detailed),
            VariantConfig(name: "Casual", tone: .casual, length: .medium, type: .detailed),
            VariantConfig(name: "Brief", tone: .professional, length: .short, type: .brief),
            VariantConfig(name: "Formal", tone: .formal, length: .medium, type: .detailed),
            VariantConfig(name: "Friendly", tone: .friendly, length: .medium, type: .detailed)
        ]
        
        return Array(allVariants.prefix(count))
    }
    
    private func generateVariant(
        context: GenerationContext,
        variant: VariantConfig,
        index: Int
    ) async throws -> ResponseSuggestion {
        let content = try await generateSingleResponse(
            context: context,
            tone: variant.tone,
            length: variant.length
        )
        
        // Calculate confidence based on context quality
        let confidence = calculateConfidence(context: context, variant: variant)
        
        // Build reasoning
        let reasoning = buildReasoning(context: context, variant: variant)
        
        // Generate variations for this suggestion
        let variations = try await generateVariations(
            baseContent: content,
            context: context,
            variant: variant
        )
        
        return ResponseSuggestion(
            id: UUID(),
            emailID: context.email.id,
            content: content,
            type: variant.type,
            confidence: confidence,
            reasoning: reasoning,
            tone: mapTone(variant.tone),
            estimatedComposeTime: estimateComposeTime(length: variant.length),
            source: ResponseGeneratorPlugin.pluginIdentifier,
            variations: variations
        )
    }
    
    private func buildPrompt(context: GenerationContext, tone: ResponseTone, length: ResponseLength) -> String {
        var prompt = ""
        
        // Add RAG examples if available
        if !context.ragExamples.isEmpty {
            prompt += "=== SIMILAR PAST EMAILS ===\n"
            for (index, example) in context.ragExamples.prefix(3).enumerated() {
                prompt += "Example \(index + 1) (\(Int(example.similarity * 100))% match):\n"
                prompt += "Incoming: \(example.incomingEmail.prefix(200))...\n"
                prompt += "Response: \(example.userResponse.prefix(300))...\n\n"
            }
        }
        
        // Add thread context if available
        if !context.threadHistory.isEmpty {
            prompt += "=== CONVERSATION HISTORY ===\n"
            for email in context.threadHistory.sorted(by: { $0.date < $1.date }) {
                prompt += "From: \(email.from.displayName)\n"
                prompt += "Subject: \(email.subject)\n"
                prompt += "Date: \(formatDate(email.date))\n"
                if let body = email.bodyPlain {
                    prompt += "Content: \(body.prefix(200))...\n"
                }
                prompt += "\n"
            }
        }
        
        // Add sender context
        if let sender = context.sender {
            prompt += "=== SENDER INFO ===\n"
            prompt += "Name: \(sender.name ?? sender.email)\n"
            if let company = sender.company {
                prompt += "Company: \(company)\n"
            }
            if let relationship = sender.relationshipScore {
                prompt += "Relationship: \(relationship > 0.7 ? "Close" : relationship > 0.4 ? "Established" : "New")\n"
            }
            prompt += "\n"
        }
        
        // Add the email to respond to
        prompt += "=== EMAIL TO RESPOND TO ===\n"
        prompt += "From: \(context.email.from.displayName)\n"
        prompt += "Subject: \(context.email.subject)\n"
        if let body = context.email.bodyPlain {
            prompt += "\n\(body)\n"
        }
        
        // Add instructions
        prompt += "\n=== INSTRUCTIONS ===\n"
        prompt += "Write a \(length == .short ? "brief" : length == .long ? "detailed" : "standard") response.\n"
        prompt += "Tone: \(tone.displayName.lowercased()).\n"
        
        if let style = context.writingStyle {
            prompt += "Match the user's writing style (formality: \(style.formality)).\n"
        }
        
        // Add calendar context if scheduling-related
        if context.detectedIntent == .scheduling, let availability = context.calendarAvailability {
            prompt += "\nCalendar context:\n"
            if availability.hasConflicts {
                prompt += "- User has scheduling conflicts\n"
            }
            if let nextSlot = availability.nextAvailableSlot {
                prompt += "- Next available: \(formatDate(nextSlot))\n"
            }
            for (index, time) in availability.suggestedTimes.prefix(3).enumerated() {
                prompt += "- Suggestion \(index + 1): \(formatDate(time))\n"
            }
        }
        
        prompt += "\nPlease compose the response now:"
        
        return prompt
    }
    
    private func buildSystemPrompt(context: GenerationContext) -> String {
        var prompt = """
        You are an intelligent email writing assistant. Generate natural, contextually appropriate responses.
        
        Guidelines:
        - Be authentic and human-sounding
        - Match the formality level of the incoming email
        - Address all points raised in the email
        - Be concise but thorough
        - Use proper email etiquette
        """
        
        // Add style-specific guidance
        if let style = context.writingStyle {
            prompt += "\n\nUser's Writing Style:\n"
            prompt += "- Formality: \(style.formality.rawValue)\n"
            prompt += "- Friendliness: \(Int(style.tone.friendliness * 100))%\n"
            prompt += "- Directness: \(Int(style.tone.directness * 100))%\n"
            prompt += "- Enthusiasm: \(Int(style.tone.enthusiasm * 100))%\n"
            
            if !style.commonOpenings.isEmpty {
                prompt += "- Common greetings: \(style.commonOpenings.prefix(3).joined(separator: ", "))\n"
            }
            if !style.commonClosings.isEmpty {
                prompt += "- Common closings: \(style.commonClosings.prefix(3).joined(separator: ", "))\n"
            }
        }
        
        return prompt
    }
    
    private func buildEmailContext(from generationContext: GenerationContext) -> EmailContext? {
        // Build EmailContext from GenerationContext
        // This would contain thread information for context
        return nil // Placeholder - would be implemented with actual EmailContext
    }
    
    private func generateWithAI(request: GenerationRequest) async throws -> String {
        // Access the plugin's AI provider through the context
        guard let plugin = plugin else {
            throw SuggestionEngineError.pluginNotAvailable
        }
        
        // Get the AI provider from the plugin context
        let provider = await plugin.context.aiProvider
        
        // Generate the response
        let response = try await provider.generate(request: request)
        
        return response.text
    }
    
    private func generateVariations(
        baseContent: String,
        context: GenerationContext,
        variant: VariantConfig
    ) async throws -> [SuggestionVariation] {
        // Generate slight variations of the same suggestion
        var variations: [SuggestionVariation] = []
        
        // Shorter version
        let shortVersion = try await generateShortVersion(of: baseContent)
        variations.append(SuggestionVariation(
            name: "Shorter",
            content: shortVersion,
            description: "More concise version"
        ))
        
        // More formal version (if not already formal)
        if variant.tone != .formal {
            let formalVersion = try await generateFormalVersion(of: baseContent)
            variations.append(SuggestionVariation(
                name: "More Formal",
                content: formalVersion,
                description: "More formal tone"
            ))
        }
        
        return variations
    }
    
    private func generateShortVersion(of content: String) async throws -> String {
        // Would call AI to condense the response
        // Placeholder: return truncated version
        let sentences = content.components(separatedBy: ". ")
        return sentences.prefix(2).joined(separator: ". ") + "."
    }
    
    private func generateFormalVersion(of content: String) async throws -> String {
        // Would call AI to make response more formal
        // Placeholder: return with formal substitutions
        return content
            .replacingOccurrences(of: "Hi", with: "Dear")
            .replacingOccurrences(of: "Thanks", with: "Thank you")
            .replacingOccurrences(of: "can't", with: "cannot")
    }
    
    private func calculateConfidence(context: GenerationContext, variant: VariantConfig) -> Double {
        var score = 0.7 // Base confidence
        
        // Boost for having RAG examples
        if !context.ragExamples.isEmpty {
            let bestMatch = context.ragExamples.map { $0.similarity }.max() ?? 0
            score += bestMatch * 0.15
        }
        
        // Boost for having writing style
        if context.writingStyle != nil {
            score += 0.05
        }
        
        // Boost for thread context
        if context.threadHistory.count > 1 {
            score += 0.05
        }
        
        // Penalty for very long threads (might be confusing)
        if context.threadHistory.count > 10 {
            score -= 0.05
        }
        
        return min(0.95, max(0.5, score))
    }
    
    private func buildReasoning(context: GenerationContext, variant: VariantConfig) -> String {
        var reasons: [String] = []
        
        if !context.ragExamples.isEmpty {
            let avgSimilarity = context.ragExamples.map { $0.similarity }.reduce(0, +) / Double(context.ragExamples.count)
            reasons.append("Based on \(context.ragExamples.count) similar past emails (avg \(Int(avgSimilarity * 100))% match)")
        }
        
        if context.writingStyle != nil {
            reasons.append("Adapted to your personal writing style")
        }
        
        if !context.threadHistory.isEmpty {
            reasons.append("Considers \(context.threadHistory.count) previous messages in thread")
        }
        
        reasons.append("\(variant.name) tone appropriate for this context")
        
        return reasons.joined(separator: "; ")
    }
    
    private func mapTone(_ tone: ResponseTone) -> SuggestionTone {
        switch tone {
        case .formal: return .formal
        case .casual: return .casual
        case .friendly: return .friendly
        case .professional: return .professional
        case .assertive: return .assertive
        case .diplomatic: return .diplomatic
        case .auto: return .neutral
        }
    }
    
    private func estimateComposeTime(length: ResponseLength) -> TimeInterval {
        switch length {
        case .short: return 60 // 1 minute
        case .medium: return 180 // 3 minutes
        case .long: return 300 // 5 minutes
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

private struct VariantConfig {
    let name: String
    let tone: ResponseTone
    let length: ResponseLength
    let type: SuggestionType
}

private struct SuggestionConfiguration {
    var maxTokens: Int
    var temperature: Double
    var topP: Double
    
    static let `default` = SuggestionConfiguration(
        maxTokens: 2048,
        temperature: 0.7,
        topP: 1.0
    )
}

private struct EmailContext {
    let thread: [Email]?
}

// MARK: - Errors

private enum SuggestionEngineError: Error, LocalizedError {
    case pluginNotAvailable
    case aiProviderNotAvailable
    case generationFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .pluginNotAvailable:
            return "SuggestionEngine plugin is no longer available"
        case .aiProviderNotAvailable:
            return "AI provider is not configured or unavailable"
        case .generationFailed(let error):
            return "Failed to generate suggestion: \(error.localizedDescription)"
        }
    }
}

// MARK: - Placeholder Logger

private struct PluginLoggerPlaceholder: PluginLogger {
    func debug(_ message: String) {}
    func info(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}
}
