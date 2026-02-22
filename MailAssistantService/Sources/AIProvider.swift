//
//  AIProvider.swift
//  MailAssistantService
//

import Foundation

/// Manages AI provider connections and request routing
class AIServiceProvider {
    
    // MARK: - Properties
    
    private var providers: [String: AIProviderProtocol] = [:]
    private var activeProvider: AIProviderProtocol?
    
    // MARK: - Initialization
    
    init() {
        setupDefaultProviders()
    }
    
    // MARK: - Provider Management
    
    private func setupDefaultProviders() {
        // Register built-in providers
        providers["kimi"] = KimiProvider()
        providers["openai"] = OpenAIProvider()
        providers["anthropic"] = AnthropicProvider()
        providers["local"] = LocalProvider()
    }
    
    func setActiveProvider(_ providerID: String) throws {
        guard let provider = providers[providerID] else {
            throw AIProviderError.unknownProvider
        }
        activeProvider = provider
    }
    
    // MARK: - Request Handling
    
    func generateReplySuggestions(
        for email: EmailContent,
        count: Int = 3
    ) async throws -> [Suggestion] {
        guard let provider = activeProvider else {
            throw AIProviderError.noActiveProvider
        }
        
        let prompt = buildReplyPrompt(for: email)
        return try await provider.generateSuggestions(
            prompt: prompt,
            count: count,
            type: .reply
        )
    }
    
    func generateRewriteSuggestions(
        for text: String,
        tone: Tone = .professional
    ) async throws -> [Suggestion] {
        guard let provider = activeProvider else {
            throw AIProviderError.noActiveProvider
        }
        
        let prompt = buildRewritePrompt(for: text, tone: tone)
        return try await provider.generateSuggestions(
            prompt: prompt,
            count: 2,
            type: .rewrite
        )
    }
    
    func generateSummary(for email: EmailContent) async throws -> String {
        guard let provider = activeProvider else {
            throw AIProviderError.noActiveProvider
        }
        
        let prompt = buildSummaryPrompt(for: email)
        let suggestions = try await provider.generateSuggestions(
            prompt: prompt,
            count: 1,
            type: .summary
        )
        return suggestions.first?.text ?? ""
    }
    
    func analyzeTone(for text: String) async throws -> ToneAnalysis {
        guard let provider = activeProvider else {
            throw AIProviderError.noActiveProvider
        }
        
        let prompt = buildToneAnalysisPrompt(for: text)
        let suggestions = try await provider.generateSuggestions(
            prompt: prompt,
            count: 1,
            type: .analysis
        )
        
        // Parse the analysis result
        return ToneAnalysis(
            primaryTone: .professional,
            confidence: 0.85,
            suggestions: []
        )
    }
    
    // MARK: - Prompt Building
    
    private func buildReplyPrompt(for email: EmailContent) -> String {
        return """
        Given the following email, generate 3 concise, professional reply suggestions:
        
        Subject: \(email.subject)
        From: \(email.sender)
        Body: \(email.body.prefix(2000))
        
        Each suggestion should be brief (1-2 sentences) and appropriate for the context.
        """
    }
    
    private func buildRewritePrompt(for text: String, tone: Tone) -> String {
        return """
        Rewrite the following text in a \(tone.description) tone:
        
        "\(text)"
        
        Provide 2 alternative versions.
        """
    }
    
    private func buildSummaryPrompt(for email: EmailContent) -> String {
        return """
        Summarize the following email in 1-2 sentences, highlighting key action items:
        
        Subject: \(email.subject)
        Body: \(email.body.prefix(3000))
        """
    }
    
    private func buildToneAnalysisPrompt(for text: String) -> String {
        return """
        Analyze the tone of the following text and provide:
        1. Primary tone
        2. Confidence score
        3. Any tone adjustments needed
        
        Text: \(text.prefix(1500))
        """
    }
}

// MARK: - AI Provider Protocol

protocol AIProviderProtocol {
    var name: String { get }
    var isAvailable: Bool { get }
    
    func generateSuggestions(
        prompt: String,
        count: Int,
        type: SuggestionRequestType
    ) async throws -> [Suggestion]
}

// MARK: - Provider Implementations

class KimiProvider: AIProviderProtocol {
    let name = "Kimi"
    var isAvailable: Bool {
        // Check if API key is configured
        return UserDefaults.standard.string(forKey: "kimi_api_key") != nil
    }
    
    func generateSuggestions(
        prompt: String,
        count: Int,
        type: SuggestionRequestType
    ) async throws -> [Suggestion] {
        // Implementation would call Kimi API
        return []
    }
}

class OpenAIProvider: AIProviderProtocol {
    let name = "OpenAI"
    var isAvailable: Bool {
        return UserDefaults.standard.string(forKey: "openai_api_key") != nil
    }
    
    func generateSuggestions(
        prompt: String,
        count: Int,
        type: SuggestionRequestType
    ) async throws -> [Suggestion] {
        return []
    }
}

class AnthropicProvider: AIProviderProtocol {
    let name = "Anthropic"
    var isAvailable: Bool {
        return UserDefaults.standard.string(forKey: "anthropic_api_key") != nil
    }
    
    func generateSuggestions(
        prompt: String,
        count: Int,
        type: SuggestionRequestType
    ) async throws -> [Suggestion] {
        return []
    }
}

class LocalProvider: AIProviderProtocol {
    let name = "Local Model"
    var isAvailable: Bool {
        // Check if local model is available
        return false
    }
    
    func generateSuggestions(
        prompt: String,
        count: Int,
        type: SuggestionRequestType
    ) async throws -> [Suggestion] {
        return []
    }
}

// MARK: - Supporting Types

enum AIProviderError: Error {
    case unknownProvider
    case noActiveProvider
    case apiError(String)
    case rateLimited
    case invalidResponse
}

enum SuggestionRequestType {
    case reply
    case rewrite
    case summary
    case analysis
}

enum Tone: String, CaseIterable {
    case professional
    case friendly
    case formal
    case casual
    case urgent
    
    var description: String {
        switch self {
        case .professional: return "professional and clear"
        case .friendly: return "warm and friendly"
        case .formal: return "formal and respectful"
        case .casual: return "casual and conversational"
        case .urgent: return "urgent and direct"
        }
    }
}

struct ToneAnalysis {
    let primaryTone: Tone
    let confidence: Double
    let suggestions: [String]
}
