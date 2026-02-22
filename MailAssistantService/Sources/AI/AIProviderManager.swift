import Foundation
import PluginAPI
import Shared

// MARK: - Errors

public enum AIProviderError: Error, LocalizedError {
    case noProviderAvailable
    case providerNotFound(id: String)
    case providerNotConfigured(id: String)
    case allProvidersFailed([Error])
    case invalidConfiguration(reason: String)
    case rateLimited(providerId: String, retryAfter: TimeInterval?)
    
    public var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            return "No AI provider is available. Please configure an AI provider in settings."
        case .providerNotFound(let id):
            return "AI provider '\(id)' not found."
        case .providerNotConfigured(let id):
            return "AI provider '\(id)' is not configured. Please check your API key."
        case .allProvidersFailed(let errors):
            let errorList = errors.map { $0.localizedDescription }.joined(separator: "; ")
            return "All AI providers failed: \(errorList)"
        case .invalidConfiguration(let reason):
            return "Invalid AI provider configuration: \(reason)"
        case .rateLimited(let providerId, let retryAfter):
            let retryMsg = retryAfter.map { " Retry after \($0) seconds." } ?? ""
            return "Provider '\(providerId)' rate limited.\(retryMsg)"
        }
    }
}

// MARK: - Provider Registration

public struct ProviderRegistration {
    let provider: AIProviderPlugin
    let priority: Int
    let isFallback: Bool
    let maxRetries: Int
    
    public init(
        provider: AIProviderPlugin,
        priority: Int = 0,
        isFallback: Bool = false,
        maxRetries: Int = 3
    ) {
        self.provider = provider
        self.priority = priority
        self.isFallback = isFallback
        self.maxRetries = maxRetries
    }
}

// MARK: - Configuration

public struct AIProviderConfiguration: Codable, Equatable {
    public var activeProviderId: String?
    public var fallbackProviderIds: [String]
    public var defaultModel: String?
    public var defaultTemperature: Double
    public var defaultMaxTokens: Int
    public var enableStreaming: Bool
    public var timeoutSeconds: TimeInterval
    
    public init(
        activeProviderId: String? = nil,
        fallbackProviderIds: [String] = [],
        defaultModel: String? = nil,
        defaultTemperature: Double = 0.7,
        defaultMaxTokens: Int = 2048,
        enableStreaming: Bool = true,
        timeoutSeconds: TimeInterval = 60
    ) {
        self.activeProviderId = activeProviderId
        self.fallbackProviderIds = fallbackProviderIds
        self.defaultModel = defaultModel
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
        self.enableStreaming = enableStreaming
        self.timeoutSeconds = timeoutSeconds
    }
    
    public static let `default` = AIProviderConfiguration()
}

// MARK: - AIProviderManager

public actor AIProviderManager {
    
    // MARK: - Singleton
    
    public static let shared = AIProviderManager()
    
    // MARK: - Properties
    
    private var registrations: [String: ProviderRegistration] = [:]
    private var configuration: AIProviderConfiguration = .default
    private var logger = Logger(subsystem: "kimimail.ai", category: "AIProviderManager")
    
    // Track provider health status
    private var providerHealth: [String: ProviderHealth] = [:]
    
    // MARK: - Types
    
    private struct ProviderHealth {
        var isHealthy: Bool
        var lastFailure: Date?
        var failureCount: Int
        var consecutiveSuccesses: Int
        var averageResponseTime: TimeInterval
        
        mutating func recordSuccess(responseTime: TimeInterval) {
            isHealthy = true
            consecutiveSuccesses += 1
            failureCount = 0
            // Exponential moving average for response time
            let alpha = 0.3
            averageResponseTime = (alpha * responseTime) + ((1 - alpha) * averageResponseTime)
        }
        
        mutating func recordFailure() {
            consecutiveSuccesses = 0
            failureCount += 1
            lastFailure = Date()
            // Mark unhealthy after 3 consecutive failures
            if failureCount >= 3 {
                isHealthy = false
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Management
    
    public func setConfiguration(_ config: AIProviderConfiguration) async {
        configuration = config
        await saveConfiguration()
        logger.info("AI provider configuration updated")
    }
    
    public func getConfiguration() -> AIProviderConfiguration {
        configuration
    }
    
    private func loadConfiguration() {
        // Load from UserDefaults or persistent storage
        if let data = UserDefaults.standard.data(forKey: "aiProviderConfiguration"),
           let config = try? JSONDecoder().decode(AIProviderConfiguration.self, from: data) {
            configuration = config
            logger.info("Loaded AI provider configuration")
        }
    }
    
    private func saveConfiguration() async {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "aiProviderConfiguration")
        }
    }
    
    // MARK: - Provider Registration
    
    public func registerProvider(_ registration: ProviderRegistration) {
        let id = registration.provider.id
        registrations[id] = registration
        providerHealth[id] = ProviderHealth(
            isHealthy: true,
            lastFailure: nil,
            failureCount: 0,
            consecutiveSuccesses: 0,
            averageResponseTime: 1.0
        )
        logger.info("Registered AI provider: \(id)")
    }
    
    public func unregisterProvider(id: String) {
        registrations.removeValue(forKey: id)
        providerHealth.removeValue(forKey: id)
        logger.info("Unregistered AI provider: \(id)")
    }
    
    public func getRegisteredProviders() -> [AIProviderPlugin] {
        registrations.values
            .sorted { $0.priority > $1.priority }
            .map { $0.provider }
    }
    
    public func getProvider(id: String) -> AIProviderPlugin? {
        registrations[id]?.provider
    }
    
    // MARK: - Provider Selection
    
    /// Returns the currently active provider, or the highest priority available provider
    public func getActiveProvider() async throws -> AIProviderPlugin {
        // First, try the explicitly configured active provider
        if let activeId = configuration.activeProviderId,
           let registration = registrations[activeId] {
            let health = providerHealth[activeId]
            if health?.isHealthy ?? true {
                return registration.provider
            }
            logger.warning("Active provider \(activeId) is unhealthy, trying fallbacks")
        }
        
        // Try fallback providers in order
        for fallbackId in configuration.fallbackProviderIds {
            if let registration = registrations[fallbackId],
               providerHealth[fallbackId]?.isHealthy ?? true {
                logger.info("Using fallback provider: \(fallbackId)")
                return registration.provider
            }
        }
        
        // Finally, try any healthy registered provider sorted by priority
        let availableProviders = registrations.values
            .filter { providerHealth[$0.provider.id]?.isHealthy ?? true }
            .sorted { $0.priority > $1.priority }
        
        if let firstAvailable = availableProviders.first {
            return firstAvailable.provider
        }
        
        throw AIProviderError.noProviderAvailable
    }
    
    /// Sets the active provider by ID
    public func setActiveProvider(id: String) async throws {
        guard registrations[id] != nil else {
            throw AIProviderError.providerNotFound(id: id)
        }
        
        var newConfig = configuration
        newConfig.activeProviderId = id
        await setConfiguration(newConfig)
    }
    
    // MARK: - Generation (Non-streaming)
    
    public func generate(
        request: GenerationRequest,
        providerId: String? = nil
    ) async throws -> GenerationResponse {
        let providers = try await resolveProviders(for: providerId)
        var errors: [Error] = []
        
        for provider in providers {
            do {
                let startTime = Date()
                let response = try await executeGeneration(provider: provider, request: request)
                
                // Record success
                await recordSuccess(providerId: provider.id, responseTime: Date().timeIntervalSince(startTime))
                
                return response
            } catch {
                await recordFailure(providerId: provider.id)
                errors.append(error)
                logger.error("Provider \(provider.id) failed: \(error.localizedDescription)")
                
                // Check if we should retry with this provider
                if let registration = registrations[provider.id],
                   errors.count <= registration.maxRetries,
                   isRetryableError(error) {
                    logger.info("Retrying with provider \(provider.id)...")
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(errors.count)) * 1_000_000_000))
                    continue
                }
            }
        }
        
        throw AIProviderError.allProvidersFailed(errors)
    }
    
    // MARK: - Generation (Streaming)
    
    public func stream(
        request: GenerationRequest,
        providerId: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let providers = try await resolveProviders(for: providerId)
        
        return AsyncThrowingStream { continuation in
            Task {
                var errors: [Error] = []
                
                for provider in providers {
                    do {
                        let startTime = Date()
                        let stream = provider.stream(request: request)
                        
                        for try await chunk in stream {
                            continuation.yield(chunk)
                        }
                        
                        // Record success
                        await recordSuccess(
                            providerId: provider.id,
                            responseTime: Date().timeIntervalSince(startTime)
                        )
                        
                        continuation.finish()
                        return
                    } catch {
                        await recordFailure(providerId: provider.id)
                        errors.append(error)
                        logger.error("Provider \(provider.id) streaming failed: \(error.localizedDescription)")
                    }
                }
                
                continuation.finish(throwing: AIProviderError.allProvidersFailed(errors))
            }
        }
    }
    
    // MARK: - Validation
    
    public func validateConfiguration(providerId: String) async -> Result<Bool, AIProviderError> {
        guard let provider = registrations[providerId]?.provider else {
            return .failure(.providerNotFound(id: providerId))
        }
        
        do {
            let isValid = try await provider.validateConfiguration()
            return .success(isValid)
        } catch {
            return .failure(.invalidConfiguration(reason: error.localizedDescription))
        }
    }
    
    public func validateAllConfigurations() async -> [String: Result<Bool, AIProviderError>] {
        var results: [String: Result<Bool, AIProviderError>] = [:]
        
        for (id, registration) in registrations {
            results[id] = await validateConfiguration(providerId: id)
        }
        
        return results
    }
    
    // MARK: - Health Management
    
    private func recordSuccess(providerId: String, responseTime: TimeInterval) async {
        providerHealth[providerId]?.recordSuccess(responseTime: responseTime)
    }
    
    private func recordFailure(providerId: String) async {
        providerHealth[providerId]?.recordFailure()
    }
    
    public func getProviderHealth(providerId: String) -> (isHealthy: Bool, averageResponseTime: TimeInterval)? {
        guard let health = providerHealth[providerId] else { return nil }
        return (health.isHealthy, health.averageResponseTime)
    }
    
    public func resetProviderHealth(providerId: String) {
        providerHealth[providerId] = ProviderHealth(
            isHealthy: true,
            lastFailure: nil,
            failureCount: 0,
            consecutiveSuccesses: 0,
            averageResponseTime: 1.0
        )
    }
    
    // MARK: - Private Helpers
    
    private func resolveProviders(for specificId: String?) async throws -> [AIProviderPlugin] {
        if let id = specificId {
            guard let provider = registrations[id]?.provider else {
                throw AIProviderError.providerNotFound(id: id)
            }
            return [provider]
        }
        
        return try await getActiveProviderWithFallbacks()
    }
    
    private func getActiveProviderWithFallbacks() async throws -> [AIProviderPlugin] {
        var providers: [AIProviderPlugin] = []
        
        // Primary provider
        if let activeId = configuration.activeProviderId,
           let registration = registrations[activeId] {
            providers.append(registration.provider)
        }
        
        // Fallback providers
        for fallbackId in configuration.fallbackProviderIds {
            if fallbackId != configuration.activeProviderId,
               let registration = registrations[fallbackId] {
                providers.append(registration.provider)
            }
        }
        
        // Any other healthy providers sorted by priority
        let remaining = registrations.values
            .filter { registration in !providers.contains(where: { $0.id == registration.provider.id }) }
            .filter { providerHealth[$0.provider.id]?.isHealthy ?? true }
            .sorted { $0.priority > $1.priority }
        
        providers.append(contentsOf: remaining.map { $0.provider })
        
        guard !providers.isEmpty else {
            throw AIProviderError.noProviderAvailable
        }
        
        return providers
    }
    
    private func executeGeneration(
        provider: AIProviderPlugin,
        request: GenerationRequest
    ) async throws -> GenerationResponse {
        // Apply default configuration values if not specified
        var modifiedRequest = request
        if modifiedRequest.temperature == nil {
            modifiedRequest = GenerationRequest(
                prompt: modifiedRequest.prompt,
                systemPrompt: modifiedRequest.systemPrompt,
                context: modifiedRequest.context,
                style: modifiedRequest.style,
                model: modifiedRequest.model ?? configuration.defaultModel,
                temperature: configuration.defaultTemperature,
                maxTokens: modifiedRequest.maxTokens ?? configuration.defaultMaxTokens,
                stream: false
            )
        }
        
        return try await provider.generate(request: modifiedRequest)
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Check for network-related errors that might succeed on retry
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorDataNotAllowed:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}

// MARK: - Convenience Extensions

public extension AIProviderManager {
    /// Quick generate with minimal parameters
    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        context: EmailContext? = nil,
        style: WritingStyle? = nil
    ) async throws -> GenerationResponse {
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            context: context,
            style: style,
            model: nil,
            temperature: nil,
            maxTokens: nil,
            stream: false
        )
        return try await generate(request: request)
    }
    
    /// Stream with minimal parameters
    func stream(
        prompt: String,
        systemPrompt: String? = nil,
        context: EmailContext? = nil,
        style: WritingStyle? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            context: context,
            style: style,
            model: nil,
            temperature: nil,
            maxTokens: nil,
            stream: true
        )
        return try await stream(request: request)
    }
}
