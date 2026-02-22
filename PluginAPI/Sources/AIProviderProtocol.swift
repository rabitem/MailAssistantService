import Foundation
import SwiftUI

// MARK: - Generation Request

public struct GenerationRequest: Sendable {
    public let prompt: String
    public let systemPrompt: String?
    public let context: EmailContext?
    public let style: WritingStyle?
    public let model: String?
    public let temperature: Double?
    public let maxTokens: Int?
    public let stream: Bool
    
    public init(
        prompt: String,
        systemPrompt: String? = nil,
        context: EmailContext? = nil,
        style: WritingStyle? = nil,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool = false
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.context = context
        self.style = style
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

// MARK: - Generation Response

public struct GenerationResponse: Sendable {
    public let text: String
    public let model: String
    public let tokensUsed: Int
    public let finishReason: String
    
    public init(
        text: String,
        model: String,
        tokensUsed: Int,
        finishReason: String
    ) {
        self.text = text
        self.model = model
        self.tokensUsed = tokensUsed
        self.finishReason = finishReason
    }
}

// MARK: - Model

public struct Model: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let maxTokens: Int
    public let contextWindow: Int
    public let supportsStreaming: Bool
    public let pricing: Pricing
    
    public init(
        id: String,
        name: String,
        description: String,
        maxTokens: Int,
        contextWindow: Int,
        supportsStreaming: Bool,
        pricing: Pricing
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.maxTokens = maxTokens
        self.contextWindow = contextWindow
        self.supportsStreaming = supportsStreaming
        self.pricing = pricing
    }
    
    public struct Pricing: Sendable {
        public let inputPer1K: Double
        public let outputPer1K: Double
        
        public init(inputPer1K: Double, outputPer1K: Double) {
            self.inputPer1K = inputPer1K
            self.outputPer1K = outputPer1K
        }
    }
}

// MARK: - AI Provider Plugin Protocol

public protocol AIProviderPlugin: Plugin {
    /// List available models
    func availableModels() async -> [Model]
    
    /// Generate completion
    func generate(request: GenerationRequest) async throws -> GenerationResponse
    
    /// Stream completion (for real-time UI)
    func stream(request: GenerationRequest) -> AsyncThrowingStream<String, Error>
    
    /// Validate API key/configuration
    func validateConfiguration() async throws -> Bool
}
