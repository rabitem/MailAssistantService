import Foundation

// MARK: - Kimi API Client

public actor KimiAPI {
    
    // MARK: - Properties
    
    private var apiKey: String?
    private let baseURL: String
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "kimimail.ai", category: "KimiAPI")
    
    // MARK: - Initialization
    
    public init(apiKey: String? = nil, baseURL: String = "https://api.moonshot.cn/v1", timeout: TimeInterval = 60) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.urlSession = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Configuration
    
    public func updateAPIKey(_ apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Non-streaming Completion
    
    public func createCompletion(request: KimiCompletionRequest) async throws -> KimiCompletionResponse {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw KimiAPIError.missingAPIKey
        }
        
        let endpoint = "\(baseURL)/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw KimiAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Encode request body
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw KimiAPIError.encodingError(error)
        }
        
        logger.debug("Sending completion request to \(endpoint)")
        
        // Execute request
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        // Handle HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KimiAPIError.invalidResponse
        }
        
        // Check for errors
        if httpResponse.statusCode != 200 {
            let errorResponse = try? decoder.decode(KimiErrorResponse.self, from: data)
            throw handleHTTPError(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
        }
        
        // Decode response
        do {
            let completionResponse = try decoder.decode(KimiCompletionResponse.self, from: data)
            logger.debug("Received completion response with \(completionResponse.choices.count) choices")
            return completionResponse
        } catch {
            throw KimiAPIError.decodingError(error)
        }
    }
    
    // MARK: - Streaming Completion
    
    public func streamCompletion(request: KimiCompletionRequest) -> AsyncThrowingStream<KimiCompletionChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = self.apiKey, !apiKey.isEmpty else {
                        throw KimiAPIError.missingAPIKey
                    }
                    
                    var streamRequest = request
                    streamRequest.stream = true
                    
                    let endpoint = "\(self.baseURL)/chat/completions"
                    guard let url = URL(string: endpoint) else {
                        throw KimiAPIError.invalidURL
                    }
                    
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try self.encoder.encode(streamRequest)
                    
                    self.logger.debug("Starting streaming completion")
                    
                    // Use bytes for SSE parsing
                    let (bytes, response) = try await self.urlSession.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw KimiAPIError.invalidResponse
                    }
                    
                    if httpResponse.statusCode != 200 {
                        let data = try await bytes.reduce(into: Data()) { $0.append($1) }
                        let errorResponse = try? self.decoder.decode(KimiErrorResponse.self, from: data)
                        throw self.handleHTTPError(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
                    }
                    
                    // Parse SSE stream
                    var buffer = ""
                    
                    for try await byte in bytes {
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        // Check for line ending (SSE uses \n\n to separate events)
                        if buffer.hasSuffix("\n\n") || buffer.hasSuffix("\r\n\r\n") {
                            let lines = buffer.split(separator: "\n", omittingEmptySubsequences: true)
                            
                            for line in lines {
                                let lineStr = String(line).trimmingCharacters(in: .whitespaces)
                                
                                // Parse SSE data line
                                if lineStr.hasPrefix("data: ") {
                                    let dataContent = String(lineStr.dropFirst(6))
                                    
                                    // Check for stream end
                                    if dataContent == "[DONE]" {
                                        continuation.finish()
                                        return
                                    }
                                    
                                    // Parse JSON chunk
                                    if let data = dataContent.data(using: .utf8) {
                                        do {
                                            let chunk = try self.decoder.decode(KimiCompletionChunk.self, from: data)
                                            continuation.yield(chunk)
                                        } catch {
                                            self.logger.error("Failed to decode chunk: \(error)")
                                        }
                                    }
                                }
                            }
                            
                            buffer = ""
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Model List
    
    public func listModels() async throws -> [KimiModel] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw KimiAPIError.missingAPIKey
        }
        
        let endpoint = "\(baseURL)/models"
        guard let url = URL(string: endpoint) else {
            throw KimiAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw KimiAPIError.invalidResponse
        }
        
        let modelList = try decoder.decode(KimiModelList.self, from: data)
        return modelList.data
    }
    
    // MARK: - Error Handling
    
    private func handleHTTPError(statusCode: Int, errorResponse: KimiErrorResponse?) -> KimiAPIError {
        switch statusCode {
        case 400:
            return .badRequest(errorResponse?.error.message ?? "Invalid request")
        case 401:
            return .unauthorized
        case 403:
            return .forbidden(errorResponse?.error.message)
        case 429:
            let retryAfter = errorResponse?.error.retryAfter
            return .rateLimited(retryAfter: retryAfter)
        case 500...599:
            return .serverError(statusCode: statusCode, message: errorResponse?.error.message)
        default:
            return .unknown(statusCode: statusCode, message: errorResponse?.error.message)
        }
    }
}

// MARK: - Request Models

public struct KimiCompletionRequest: Codable {
    public var model: String
    public var messages: [KimiMessage]
    public var temperature: Double?
    public var maxTokens: Int?
    public var stream: Bool
    public var topP: Double?
    public var frequencyPenalty: Double?
    public var presencePenalty: Double?
    public var stop: [String]?
    
    public init(
        model: String,
        messages: [KimiMessage],
        temperature: Double? = 0.7,
        maxTokens: Int? = 2048,
        stream: Bool = false,
        topP: Double? = 1.0,
        frequencyPenalty: Double? = 0.0,
        presencePenalty: Double? = 0.0,
        stop: [String]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stop = stop
    }
}

// MARK: - Response Models

public struct KimiCompletionResponse: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [KimiChoice]
    public let usage: KimiUsage?
}

public struct KimiChoice: Codable {
    public let index: Int
    public let message: KimiMessage
    public let finishReason: String?
}

public struct KimiMessage: Codable, Equatable {
    public let role: KimiRole
    public let content: String
    
    public init(role: KimiRole, content: String) {
        self.role = role
        self.content = content
    }
}

public enum KimiRole: String, Codable, Equatable {
    case system
    case user
    case assistant
}

public struct KimiUsage: Codable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
}

// MARK: - Streaming Models

public struct KimiCompletionChunk: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [KimiChunkChoice]
}

public struct KimiChunkChoice: Codable {
    public let index: Int
    public let delta: KimiDelta
    public let finishReason: String?
}

public struct KimiDelta: Codable {
    public let role: KimiRole?
    public let content: String?
}

// MARK: - Model List

public struct KimiModelList: Codable {
    public let object: String
    public let data: [KimiModel]
}

public struct KimiModel: Codable, Identifiable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String
}

// MARK: - Error Response

public struct KimiErrorResponse: Codable {
    public let error: KimiError
}

public struct KimiError: Codable {
    public let message: String
    public let type: String
    public let code: String?
    public let retryAfter: TimeInterval?
}

// MARK: - Errors

public enum KimiAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case encodingError(Error)
    case decodingError(Error)
    case badRequest(String)
    case unauthorized
    case forbidden(String?)
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String?)
    case unknown(statusCode: Int, message: String?)
    case networkError(Error)
    case streamError(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized:
            return "Invalid API key"
        case .forbidden(let message):
            return "Access forbidden: \(message ?? "Unknown reason")"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Retry after \(retry) seconds"
            }
            return "Rate limit exceeded"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .unknown(let code, let message):
            return "Unknown error (\(code)): \(message ?? "Unknown")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .streamError(let message):
            return "Streaming error: \(message)"
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError, .networkError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Logger Stub

private struct Logger {
    let subsystem: String
    let category: String
    
    func debug(_ message: String) {
        #if DEBUG
        print("[DEBUG][\(category)] \(message)")
        #endif
    }
    
    func info(_ message: String) {
        print("[INFO][\(category)] \(message)")
    }
    
    func warning(_ message: String) {
        print("[WARNING][\(category)] \(message)")
    }
    
    func error(_ message: String) {
        print("[ERROR][\(category)] \(message)")
    }
}
