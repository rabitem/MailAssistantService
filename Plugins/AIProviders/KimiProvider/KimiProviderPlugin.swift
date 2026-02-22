import Foundation
import PluginAPI
import Shared

// MARK: - Kimi Provider Plugin

public final class KimiProviderPlugin: NSObject, AIProviderPlugin {
    
    // MARK: - Plugin Properties
    
    public let id = "ai.kimi.provider"
    public let name = "Kimi AI Provider"
    public let version = "1.0.0"
    public let author = "KimiMail Assistant"
    
    public var permissions: [PluginPermission] {
        [
            .network,
            .keychain,
            .backgroundProcessing
        ]
    }
    
    public var dependencies: [String] = []
    
    // MARK: - Private Properties
    
    private var context: PluginContext?
    private var api: KimiAPI?
    private var logger = Logger(subsystem: "kimimail.ai", category: "KimiProvider")
    private var settings: KimiSettings = .default
    
    // Available models
    private let availableModels: [Model] = [
        Model(
            id: "kimi-k2",
            name: "Kimi K2",
            description: "Balanced performance with excellent context understanding",
            maxTokens: 8192,
            contextWindow: 128000,
            supportsStreaming: true,
            pricing: Model.Pricing(inputPer1K: 0.003, outputPer1K: 0.003)
        ),
        Model(
            id: "kimi-k2-latest",
            name: "Kimi K2 Latest",
            description: "Latest version with improved reasoning capabilities",
            maxTokens: 8192,
            contextWindow: 128000,
            supportsStreaming: true,
            pricing: Model.Pricing(inputPer1K: 0.003, outputPer1K: 0.003)
        )
    ]
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        logger.info("KimiProviderPlugin initialized")
    }
    
    // MARK: - Plugin Protocol
    
    public func initialize(context: PluginContext) async throws {
        self.context = context
        
        // Load settings
        await loadSettings()
        
        // Initialize API client
        let apiKey = await loadAPIKey()
        api = KimiAPI(
            apiKey: apiKey,
            baseURL: settings.baseURL,
            timeout: settings.timeoutSeconds
        )
        
        logger.info("KimiProviderPlugin initialized with context")
    }
    
    public func shutdown() async {
        logger.info("KimiProviderPlugin shutting down")
        api = nil
        context = nil
    }
    
    public func settingsView() -> AnyView? {
        // Would return SwiftUI view for settings
        // For now, return nil (no custom settings view)
        return nil
    }
    
    // MARK: - AIProviderPlugin Protocol
    
    public func availableModels() async -> [Model] {
        return availableModels
    }
    
    public func generate(request: GenerationRequest) async throws -> GenerationResponse {
        guard let api = api else {
            throw KimiProviderError.notInitialized
        }
        
        // Validate API key
        guard await loadAPIKey() != nil else {
            throw KimiProviderError.noAPIKey
        }
        
        logger.debug("Generating completion with model: \(request.model ?? settings.defaultModel)")
        
        // Build messages
        let messages = buildMessages(from: request)
        
        // Create completion request
        let completionRequest = KimiCompletionRequest(
            model: request.model ?? settings.defaultModel,
            messages: messages,
            temperature: request.temperature ?? settings.defaultTemperature,
            maxTokens: request.maxTokens ?? settings.defaultMaxTokens,
            stream: false,
            topP: settings.topP,
            frequencyPenalty: settings.frequencyPenalty,
            presencePenalty: settings.presencePenalty
        )
        
        // Execute with retry logic
        let response = try await executeWithRetry {
            try await api.createCompletion(request: completionRequest)
        }
        
        guard let choice = response.choices.first else {
            throw KimiProviderError.noCompletionGenerated
        }
        
        return GenerationResponse(
            text: choice.message.content,
            model: response.model,
            tokensUsed: response.usage?.totalTokens ?? 0,
            finishReason: choice.finishReason ?? "unknown"
        )
    }
    
    public func stream(request: GenerationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let api = api else {
                        throw KimiProviderError.notInitialized
                    }
                    
                    guard await loadAPIKey() != nil else {
                        throw KimiProviderError.noAPIKey
                    }
                    
                    // Build messages
                    let messages = buildMessages(from: request)
                    
                    // Create streaming request
                    let completionRequest = KimiCompletionRequest(
                        model: request.model ?? settings.defaultModel,
                        messages: messages,
                        temperature: request.temperature ?? settings.defaultTemperature,
                        maxTokens: request.maxTokens ?? settings.defaultMaxTokens,
                        stream: true,
                        topP: settings.topP,
                        frequencyPenalty: settings.frequencyPenalty,
                        presencePenalty: settings.presencePenalty
                    )
                    
                    // Stream completion
                    for try await chunk in api.streamCompletion(request: completionRequest) {
                        if let content = chunk.choices.first?.delta.content {
                            continuation.yield(content)
                        }
                        
                        // Check for finish reason
                        if let finishReason = chunk.choices.first?.finishReason,
                           finishReason != "null" && !finishReason.isEmpty {
                            break
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func validateConfiguration() async throws -> Bool {
        guard let apiKey = await loadAPIKey(), !apiKey.isEmpty else {
            return false
        }
        
        do {
            // Try a simple completion to validate
            let testRequest = KimiCompletionRequest(
                model: settings.defaultModel,
                messages: [
                    KimiMessage(role: .user, content: "Hello")
                ],
                temperature: 0.0,
                maxTokens: 5,
                stream: false
            )
            _ = try await api?.createCompletion(request: testRequest)
            return true
        } catch {
            logger.error("Configuration validation failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Configuration
    
    public func setAPIKey(_ apiKey: String) async throws {
        // Store in Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "kimi_api_key",
            kSecAttrService as String: "ai.kimi.provider",
            kSecValueData as String: apiKey.data(using: .utf8)!
        ]
        
        // Delete any existing key first
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KimiProviderError.keychainError(status: status)
        }
        
        // Update API client
        api?.updateAPIKey(apiKey)
        
        logger.info("API key stored in Keychain")
    }
    
    public func removeAPIKey() async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "kimi_api_key",
            kSecAttrService as String: "ai.kimi.provider"
        ]
        
        SecItemDelete(query as CFDictionary)
        logger.info("API key removed from Keychain")
    }
    
    // MARK: - Private Methods
    
    private func loadAPIKey() async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "kimi_api_key",
            kSecAttrService as String: "ai.kimi.provider",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
    
    private func loadSettings() async {
        if let data = UserDefaults.standard.data(forKey: "kimi_provider_settings"),
           let loaded = try? JSONDecoder().decode(KimiSettings.self, from: data) {
            settings = loaded
        }
    }
    
    private func saveSettings() async {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "kimi_provider_settings")
        }
    }
    
    private func buildMessages(from request: GenerationRequest) -> [KimiMessage] {
        var messages: [KimiMessage] = []
        
        // Add system prompt if provided
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            messages.append(KimiMessage(role: .system, content: systemPrompt))
        }
        
        // Add context as assistant/user pairs if available
        if let emailContext = request.context {
            // Add thread history as context
            if let thread = emailContext.thread {
                for email in thread.sorted(by: { ($0.sentDate ?? Date.distantPast) < ($1.sentDate ?? Date.distantPast) }) {
                    messages.append(KimiMessage(
                        role: .user,
                        content: "From: \(email.senderEmail)\nSubject: \(email.subject ?? "")\n\n\(email.bodyPlain ?? "")"
                    ))
                }
            }
        }
        
        // Add main user prompt
        messages.append(KimiMessage(role: .user, content: request.prompt))
        
        return messages
    }
    
    private func executeWithRetry<T>(
        maxRetries: Int = 3,
        operation: () async throws -> T
    ) async rethrows -> T {
        var attempts = 0
        var lastError: Error?
        
        while attempts < maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                attempts += 1
                
                if attempts < maxRetries {
                    let delay = pow(2.0, Double(attempts)) // Exponential backoff
                    logger.warning("Attempt \(attempts) failed, retrying in \(delay)s: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? KimiProviderError.maxRetriesExceeded
    }
}

// MARK: - Kimi Settings

public struct KimiSettings: Codable {
    var baseURL: String
    var defaultModel: String
    var defaultTemperature: Double
    var defaultMaxTokens: Int
    var topP: Double
    var frequencyPenalty: Double
    var presencePenalty: Double
    var timeoutSeconds: TimeInterval
    
    static let `default` = KimiSettings(
        baseURL: "https://api.moonshot.cn/v1",
        defaultModel: "kimi-k2",
        defaultTemperature: 0.7,
        defaultMaxTokens: 2048,
        topP: 1.0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0,
        timeoutSeconds: 60.0
    )
}

// MARK: - Errors

public enum KimiProviderError: Error, LocalizedError {
    case notInitialized
    case noAPIKey
    case invalidResponse
    case noCompletionGenerated
    case rateLimited(retryAfter: TimeInterval?)
    case keychainError(status: OSStatus)
    case maxRetriesExceeded
    case streamingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Kimi provider not initialized"
        case .noAPIKey:
            return "No API key configured. Please add your Kimi API key in settings."
        case .invalidResponse:
            return "Received invalid response from Kimi API"
        case .noCompletionGenerated:
            return "No completion was generated"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited. Please retry after \(Int(retry)) seconds."
            }
            return "Rate limited. Please try again later."
        case .keychainError:
            return "Failed to securely store API key"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        }
    }
}

// MARK: - SwiftUI Import for AnyView

#if canImport(SwiftUI)
import SwiftUI
#endif
