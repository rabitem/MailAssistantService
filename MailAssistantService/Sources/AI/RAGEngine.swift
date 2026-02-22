import Foundation
import PluginAPI

// MARK: - RAG Configuration

public struct RAGConfiguration: Codable, Equatable {
    public var topK: Int
    public var similarityThreshold: Double
    public var maxContextTokens: Int
    public var includeRecentEmails: Bool
    public var recentEmailsLimit: Int
    public var timeDecayEnabled: Bool
    public var timeDecayDays: Int
    
    public init(
        topK: Int = 5,
        similarityThreshold: Double = 0.7,
        maxContextTokens: Int = 2000,
        includeRecentEmails: Bool = true,
        recentEmailsLimit: Int = 10,
        timeDecayEnabled: Bool = true,
        timeDecayDays: Int = 90
    ) {
        self.topK = topK
        self.similarityThreshold = similarityThreshold
        self.maxContextTokens = maxContextTokens
        self.includeRecentEmails = includeRecentEmails
        self.recentEmailsLimit = recentEmailsLimit
        self.timeDecayEnabled = timeDecayEnabled
        self.timeDecayDays = timeDecayDays
    }
    
    public static let `default` = RAGConfiguration()
}

// MARK: - Search Result

public struct RAGSearchResult: Identifiable, Equatable {
    public let id: String
    public let email: Email
    public let similarity: Double
    public let matchedText: String
    public let userResponse: String?
    
    public init(
        id: String = UUID().uuidString,
        email: Email,
        similarity: Double,
        matchedText: String,
        userResponse: String? = nil
    ) {
        self.id = id
        self.email = email
        self.similarity = similarity
        self.matchedText = matchedText
        self.userResponse = userResponse
    }
    
    func toRAGExample() -> RAGExample {
        RAGExample(
            id: id,
            incomingEmail: matchedText,
            userResponse: userResponse ?? "",
            similarity: similarity,
            date: email.sentDate ?? Date.distantPast
        )
    }
}

// MARK: - Embedding Protocol

public protocol EmbeddingProvider: Sendable {
    /// Generate embeddings for text
    func embed(text: String) async throws -> [Float]
    
    /// Batch embed multiple texts
    func embed(batch: [String]) async throws -> [[Float]]
    
    /// Embedding dimension size
    var dimension: Int { get }
}

// MARK: - Vector Store Protocol

public protocol VectorStore: Sendable {
    /// Store an embedding for an email
    func store(emailId: String, embedding: [Float], metadata: [String: String]) async throws
    
    /// Search for similar embeddings
    func search(
        query: [Float],
        topK: Int,
        threshold: Double
    ) async throws -> [(emailId: String, similarity: Double, metadata: [String: String])]
    
    /// Delete embedding for an email
    func delete(emailId: String) async throws
    
    /// Check if email has embedding
    func hasEmbedding(emailId: String) async -> Bool
}

// MARK: - RAGEngine

public actor RAGEngine {
    
    // MARK: - Singleton
    
    public static let shared = RAGEngine()
    
    // MARK: - Properties
    
    private var embeddingProvider: EmbeddingProvider?
    private var vectorStore: VectorStore?
    private var configuration: RAGConfiguration = .default
    private var logger = Logger(subsystem: "kimimail.ai", category: "RAGEngine")
    
    // Cache for embeddings to avoid re-computing
    private var embeddingCache: [String: [Float]] = [:]
    private let maxCacheSize = 1000
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    public func configure(
        embeddingProvider: EmbeddingProvider? = nil,
        vectorStore: VectorStore? = nil,
        configuration: RAGConfiguration? = nil
    ) {
        self.embeddingProvider = embeddingProvider
        self.vectorStore = vectorStore
        if let config = configuration {
            self.configuration = config
        }
        logger.info("RAG Engine configured with embedding dimension: \(embeddingProvider?.dimension ?? 0)")
    }
    
    public func setConfiguration(_ config: RAGConfiguration) {
        configuration = config
        logger.info("RAG configuration updated")
    }
    
    public func getConfiguration() -> RAGConfiguration {
        configuration
    }
    
    // MARK: - Indexing
    
    /// Indexes an email for RAG retrieval
    public func index(email: Email) async throws {
        guard let embeddingProvider = embeddingProvider,
              let vectorStore = vectorStore else {
            logger.warning("RAG not configured, skipping indexing")
            return
        }
        
        // Skip if already indexed
        if await vectorStore.hasEmbedding(emailId: email.id) {
            logger.debug("Email \(email.id) already indexed")
            return
        }
        
        // Generate embedding for email content
        let content = prepareEmailContent(forEmbedding: email)
        let embedding = try await embeddingProvider.embed(text: content)
        
        // Store metadata
        let content = email.bodyPlain ?? email.bodyHtml?.stripHTML() ?? ""
        var metadata: [String: String] = [
            "subject": email.subject ?? "",
            "sender": email.senderEmail,
            "date": ISO8601DateFormatter().string(from: email.sentDate ?? Date()),
            "content": content
        ]
        
        // Store in vector database
        try await vectorStore.store(emailId: email.id, embedding: embedding, metadata: metadata)
        
        // Cache embedding
        cacheEmbedding(emailId: email.id, embedding: embedding)
        
        logger.debug("Indexed email \(email.id) with embedding")
    }
    
    /// Indexes a batch of emails
    public func index(emails: [Email]) async throws {
        guard let embeddingProvider = embeddingProvider,
              let vectorStore = vectorStore else {
            return
        }
        
        logger.info("Batch indexing \(emails.count) emails")
        
        // Filter already indexed emails
        let newEmails = await filterUnindexed(emails: emails)
        
        guard !newEmails.isEmpty else {
            logger.info("All emails already indexed")
            return
        }
        
        // Prepare content
        let contents = newEmails.map { prepareEmailContent(forEmbedding: $0) }
        
        // Generate embeddings in batches
        let batchSize = 32
        for i in stride(from: 0, to: contents.count, by: batchSize) {
            let end = min(i + batchSize, contents.count)
            let batchContents = Array(contents[i..<end])
            let batchEmails = Array(newEmails[i..<end])
            
            let embeddings = try await embeddingProvider.embed(batch: batchContents)
            
            // Store embeddings
            for (index, email) in batchEmails.enumerated() {
                let content = email.bodyPlain ?? email.bodyHtml?.stripHTML() ?? ""
                let metadata: [String: String] = [
                    "subject": email.subject ?? "",
                    "sender": email.senderEmail,
                    "date": ISO8601DateFormatter().string(from: email.sentDate ?? Date()),
                    "content": content
                ]
                try await vectorStore.store(
                    emailId: email.id,
                    embedding: embeddings[index],
                    metadata: metadata
                )
                cacheEmbedding(emailId: email.id, embedding: embeddings[index])
            }
        }
        
        logger.info("Successfully indexed \(newEmails.count) emails")
    }
    
    /// Remove email from RAG index
    public func remove(emailId: String) async throws {
        try await vectorStore?.delete(emailId: emailId)
        embeddingCache.removeValue(forKey: emailId)
        logger.debug("Removed email \(emailId) from RAG index")
    }
    
    // MARK: - Retrieval
    
    /// Retrieves similar emails for a given query
    public func retrieveSimilar(
        query: String,
        context: EmailContext? = nil,
        limit: Int? = nil
    ) async throws -> [RAGSearchResult] {
        guard let embeddingProvider = embeddingProvider,
              let vectorStore = vectorStore else {
            logger.warning("RAG not configured, returning empty results")
            return []
        }
        
        let effectiveLimit = limit ?? configuration.topK
        
        // Generate query embedding
        let queryEmbedding = try await embeddingProvider.embed(text: query)
        
        // Search vector store
        let results = try await vectorStore.search(
            query: queryEmbedding,
            topK: effectiveLimit * 2, // Get more results for filtering
            threshold: configuration.similarityThreshold
        )
        
        // Convert to RAGSearchResults and apply time decay if enabled
        var searchResults: [RAGSearchResult] = []
        for result in results {
            // Load email details from database
            if let email = try await loadEmail(emailId: result.emailId) {
                let decayedSimilarity = applyTimeDecay(
                    similarity: result.similarity,
                    date: email.sentDate ?? Date.distantPast
                )
                
                searchResults.append(RAGSearchResult(
                    email: email,
                    similarity: decayedSimilarity,
                    matchedText: result.metadata["content"] ?? email.bodyPlain ?? "",
                    userResponse: nil // Would be loaded from sent email thread
                ))
            }
        }
        
        // Sort by decayed similarity and take top K
        searchResults.sort { $0.similarity > $1.similarity }
        return Array(searchResults.prefix(effectiveLimit))
    }
    
    /// Retrieves similar emails using an email as the query
    public func retrieveSimilar(to email: Email, limit: Int? = nil) async throws -> [RAGSearchResult] {
        let query = prepareEmailContent(forEmbedding: email)
        return try await retrieveSimilar(
            query: query,
            context: EmailContext(email: email),
            limit: limit
        )
    }
    
    /// Gets RAG examples for prompt construction
    public func getRAGExamples(
        for email: Email,
        style: WritingStyle? = nil
    ) async throws -> [RAGExample] {
        let results = try await retrieveSimilar(to: email)
        
        // Filter to only include emails where we have sent responses
        var examples: [RAGExample] = []
        for result in results {
            if let response = await findUserResponse(to: result.email) {
                examples.append(RAGExample(
                    incomingEmail: result.matchedText,
                    userResponse: response,
                    similarity: result.similarity,
                    date: result.email.sentDate ?? Date.distantPast
                ))
            }
        }
        
        return examples
    }
    
    // MARK: - Context Assembly
    
    /// Assembles a complete context for response generation
    public func assembleContext(
        for email: Email,
        threadEmails: [Email] = [],
        userStyle: WritingStyle? = nil
    ) async throws -> PromptContext {
        
        // Get RAG examples
        let ragExamples = try await getRAGExamples(for: email, style: userStyle)
        
        // Get sender contact info (would be loaded from database)
        let senderContact = try? await loadContact(email: email.senderEmail)
        
        // Build and return prompt context
        return PromptContext(
            email: email,
            threadContext: threadEmails,
            senderContact: senderContact,
            userWritingStyle: userStyle,
            ragExamples: ragExamples.map { $0 },
            tone: .auto,
            length: .medium,
            purpose: detectPurpose(from: email)
        )
    }
    
    // MARK: - Private Helpers
    
    private func prepareEmailContent(forEmbedding email: Email) -> String {
        var content = ""
        
        // Include subject with weight
        if let subject = email.subject, !subject.isEmpty {
            content += "Subject: \(subject)\n\n"
        }
        
        // Include sender context
        content += "From: \(email.senderName ?? email.senderEmail)\n"
        
        // Include body
        let body = email.bodyPlain ?? email.bodyHtml?.stripHTML() ?? ""
        content += "\n\(body)"
        
        return content
    }
    
    private func applyTimeDecay(similarity: Double, date: Date) -> Double {
        guard configuration.timeDecayEnabled else { return similarity }
        
        let daysSince = Date().timeIntervalSince(date) / (24 * 60 * 60)
        let decayFactor = max(0, 1.0 - (daysSince / Double(configuration.timeDecayDays)))
        
        // Blend original similarity with decay factor
        return (similarity * 0.7) + (decayFactor * 0.3 * similarity)
    }
    
    private func cacheEmbedding(emailId: String, embedding: [Float]) {
        // Simple LRU-like cache: remove random entries if full
        if embeddingCache.count >= maxCacheSize {
            let keysToRemove = Array(embeddingCache.keys).prefix(maxCacheSize / 10)
            for key in keysToRemove {
                embeddingCache.removeValue(forKey: key)
            }
        }
        embeddingCache[emailId] = embedding
    }
    
    private func filterUnindexed(emails: [Email]) async -> [Email] {
        guard let vectorStore = vectorStore else { return emails }
        
        var unindexed: [Email] = []
        for email in emails {
            if !(await vectorStore.hasEmbedding(emailId: email.id)) {
                unindexed.append(email)
            }
        }
        return unindexed
    }
    
    private func loadEmail(emailId: String) async throws -> Email? {
        // Query database through plugin context or shared database manager
        // This implementation uses a shared DatabaseManager if available
        guard let databaseManager = await getDatabaseManager() else {
            logger.warning("DatabaseManager not available for loading email")
            return nil
        }
        return try await databaseManager.fetchEmail(id: emailId)
    }
    
    private func loadContact(email: String) async throws -> Contact? {
        // Query database through plugin context or shared database manager
        guard let databaseManager = await getDatabaseManager() else {
            logger.warning("DatabaseManager not available for loading contact")
            return nil
        }
        return try await databaseManager.fetchContact(email: email)
    }
    
    private func findUserResponse(to email: Email) async -> String? {
        // Search for user's sent response to this email
        // Look for emails in the thread where the user is the sender
        guard let databaseManager = await getDatabaseManager() else {
            logger.warning("DatabaseManager not available for finding user response")
            return nil
        }
        
        do {
            // Search for replies in the same thread/conversation
            let threadId = email.threadId ?? email.id
            let responses = try await databaseManager.fetchResponsesInThread(threadId: threadId, after: email.sentDate)
            
            // Return the first (earliest) user response found
            return responses.first?.bodyPlain
        } catch {
            logger.error("Failed to find user response: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Database Manager Helper
    
    private func getDatabaseManager() async -> DatabaseManager? {
        // Try to get the shared database manager instance
        // This is a singleton pattern used throughout the app
        return await DatabaseManager.shared
    }
    
    // MARK: - Database Manager Protocol
    
    /// Protocol for database operations required by RAGEngine
    public protocol DatabaseManager: Sendable {
        static var shared: DatabaseManager { get }
        func fetchEmail(id: String) async throws -> Email?
        func fetchContact(email: String) async throws -> Contact?
        func fetchResponsesInThread(threadId: String, after date: Date?) async throws -> [Email]
    }
    
    private func detectPurpose(from email: Email) -> ResponsePurpose {
        let content = (email.subject ?? "") + " " + (email.bodyPlain ?? "")
        let lowercased = content.lowercased()
        
        if lowercased.contains("follow up") || lowercased.contains("following up") {
            return .followUp
        }
        if lowercased.contains("introduce") || lowercased.contains("introduction") {
            return .introduction
        }
        if lowercased.contains("thank") || lowercased.contains("appreciate") {
            return .accept
        }
        if lowercased.contains("sorry") || lowercased.contains("apologize") || lowercased.contains("apologies") {
            return .apology
        }
        if lowercased.contains("reminder") || lowercased.contains("just a reminder") {
            return .reminder
        }
        if lowercased.contains("request") || lowercased.contains("could you") || lowercased.contains("would you") {
            return .request
        }
        if lowercased.contains("unfortunately") || lowercased.contains("unable") || lowercased.contains("cannot") {
            return .decline
        }
        
        return .reply
    }
}

// MARK: - Local Embedding Provider (Fallback)

public actor LocalEmbeddingProvider: EmbeddingProvider {
    
    public let dimension: Int = 384
    
    private var wordVectors: [String: [Float]] = [:]
    private let logger = Logger(subsystem: "kimimail.ai", category: "LocalEmbeddingProvider")
    
    public init() {}
    
    public func embed(text: String) async throws -> [Float] {
        // Simple word embedding averaging for fallback
        // In production, this would use a proper sentence transformer
        
        let words = tokenize(text)
        var sum = Array(repeating: Float(0), count: dimension)
        var count = 0
        
        for word in words {
            if let vector = await getWordVector(word) {
                for i in 0..<dimension {
                    sum[i] += vector[i]
                }
                count += 1
            }
        }
        
        guard count > 0 else {
            return Array(repeating: Float(0), count: dimension)
        }
        
        // Average and normalize
        var result = sum.map { $0 / Float(count) }
        let norm = sqrt(result.map { $0 * $0 }.reduce(0, +))
        if norm > 0 {
            result = result.map { $0 / norm }
        }
        
        return result
    }
    
    public func embed(batch: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        for text in batch {
            results.append(try await embed(text: text))
        }
        return results
    }
    
    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
    
    private func getWordVector(_ word: String) async -> [Float]? {
        // Generate deterministic random vector based on word hash
        // This ensures same word gets same embedding
        if let cached = wordVectors[word] {
            return cached
        }
        
        var hasher = Hasher()
        hasher.combine(word)
        let seed = UInt64(bitPattern: Int64(hasher.finalize()))
        
        var vector = [Float]()
        var generator = SeededRandomNumberGenerator(seed: seed)
        for _ in 0..<dimension {
            vector.append(Float.random(in: -1...1, using: &generator))
        }
        
        wordVectors[word] = vector
        return vector
    }
}

// MARK: - Seeded Random Generator

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        // Simple xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

// MARK: - String Extensions

private extension String {
    func stripHTML() -> String {
        let pattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return self
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
    }
}
