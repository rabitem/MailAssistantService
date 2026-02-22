import Foundation
import GRDB
import OSLog

/// Vector store using sqlite-vec extension for semantic search
/// Provides embedding storage and similarity search capabilities
public final class VectorStore {
    private let logger = Logger(subsystem: "com.kimimail.assistant", category: "Database.VectorStore")
    private let dbQueue: DatabaseQueue
    private let dimensions: Int
    
    /// Distance metric for similarity search
    public enum DistanceMetric: String {
        case cosine = "cosine"
        case euclidean = "l2"
        case dot = "dot"
    }
    
    /// Configuration for the vector store
    public struct Configuration {
        public let dimensions: Int
        public let metric: DistanceMetric
        public let batchSize: Int
        
        public init(
            dimensions: Int = 1536,
            metric: DistanceMetric = .cosine,
            batchSize: Int = 100
        ) {
            self.dimensions = dimensions
            self.metric = metric
            self.batchSize = batchSize
        }
        
        /// Default configuration for OpenAI embeddings
        public static let openAI = Configuration(dimensions: 1536, metric: .cosine)
        
        /// Default configuration for smaller embeddings
        public static let compact = Configuration(dimensions: 384, metric: .cosine)
    }
    
    private let config: Configuration
    
    /// Initialize the vector store
    /// - Parameters:
    ///   - dbQueue: Database queue instance
    ///   - config: Vector store configuration
    public init(dbQueue: DatabaseQueue, config: Configuration = .openAI) throws {
        self.dbQueue = dbQueue
        self.config = config
        self.dimensions = config.dimensions
        
        try setup()
    }
    
    // MARK: - Setup
    
    private func setup() throws {
        try dbQueue.write { db in
            // Check if sqlite-vec extension is available
            do {
                let version = try String.fetchOne(db, sql: "SELECT vec_version()")
                self.logger.info("sqlite-vec version: \(version ?? "unknown")")
            } catch {
                self.logger.warning("sqlite-vec extension not available. Vector search will be limited.")
            }
            
            // Create the virtual table for vector search
            // Note: This requires sqlite-vec extension to be loaded
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS vec_emails USING vec0(
                    email_id TEXT PRIMARY KEY,
                    embedding FLOAT[\(self.dimensions)] distance_metric=\(self.config.metric.rawValue)
                )
                """)
            
            // Create index for faster lookups
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_vec_emails_id ON vec_emails(email_id)
                """)
        }
    }
    
    // MARK: - Embedding Storage
    
    /// Store an embedding for an email
    /// - Parameters:
    ///   - emailId: The email ID
    ///   - embedding: Vector embedding as array of floats
    ///   - modelName: Name of the model used to generate embedding
    public func storeEmbedding(
        emailId: String,
        embedding: [Float],
        modelName: String
    ) async throws {
        guard embedding.count == dimensions else {
            throw VectorStoreError.dimensionMismatch(
                expected: dimensions,
                actual: embedding.count
            )
        }
        
        let embeddingData = Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
        
        try await dbQueue.write { db in
            // Store in email_embeddings table
            let record = EmailEmbeddingRecord(
                id: nil,
                emailId: emailId,
                embedding: embeddingData,
                modelName: modelName,
                dimensions: embedding.count,
                createdAt: Date()
            )
            try record.insert(db, onConflict: .replace)
            
            // Also store in vec0 virtual table if available
            try self.insertIntoVecTable(db, emailId: emailId, embedding: embedding)
        }
        
        logger.debug("Stored embedding for email: \(emailId)")
    }
    
    /// Store multiple embeddings in batch
    /// - Parameters:
    ///   - embeddings: Array of (emailId, embedding) tuples
    ///   - modelName: Name of the model used
    public func storeEmbeddingsBatch(
        _ embeddings: [(emailId: String, embedding: [Float])],
        modelName: String
    ) async throws {
        try await dbQueue.write { db in
            for (emailId, embedding) in embeddings {
                guard embedding.count == self.dimensions else {
                    throw VectorStoreError.dimensionMismatch(
                        expected: self.dimensions,
                        actual: embedding.count
                    )
                }
                
                let embeddingData = Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
                
                let record = EmailEmbeddingRecord(
                    id: nil,
                    emailId: emailId,
                    embedding: embeddingData,
                    modelName: modelName,
                    dimensions: embedding.count,
                    createdAt: Date()
                )
                try record.insert(db, onConflict: .replace)
                
                // Insert into vec0 table
                try self.insertIntoVecTable(db, emailId: emailId, embedding: embedding)
            }
        }
        
        logger.info("Stored \(embeddings.count) embeddings in batch")
    }
    
    private func insertIntoVecTable(_ db: Database, emailId: String, embedding: [Float]) throws {
        // Format embedding for sqlite-vec: JSON array
        let embeddingJson = "[" + embedding.map { String($0) }.joined(separator: ",") + "]"
        
        try db.execute(sql: """
            INSERT OR REPLACE INTO vec_emails(email_id, embedding)
            VALUES (?, vec_f32(?))
            """, arguments: [emailId, embeddingJson])
    }
    
    // MARK: - Similarity Search
    
    /// Search for similar emails using vector similarity
    /// - Parameters:
    ///   - queryEmbedding: Query vector
    ///   - limit: Maximum number of results
    ///   - threshold: Minimum similarity score (0.0-1.0 for cosine)
    /// - Returns: Array of (emailId, distance) tuples
    public func searchSimilar(
        queryEmbedding: [Float],
        limit: Int = 10,
        threshold: Double? = nil
    ) async throws -> [(emailId: String, distance: Double)] {
        guard queryEmbedding.count == dimensions else {
            throw VectorStoreError.dimensionMismatch(
                expected: dimensions,
                actual: queryEmbedding.count
            )
        }
        
        let embeddingJson = "[" + queryEmbedding.map { String($0) }.joined(separator: ",") + "]"
        
        return try await dbQueue.read { db in
            // Use vec0 virtual table for similarity search
            let sql = """
                SELECT 
                    email_id,
                    distance
                FROM vec_emails
                WHERE embedding MATCH vec_f32(?)
                ORDER BY distance
                LIMIT ?
                """
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: [embeddingJson, limit])
            
            var results: [(emailId: String, distance: Double)] = []
            for row in rows {
                if let emailId = row["email_id"] as String?,
                   let distance = row["distance"] as Double? {
                    
                    // Apply threshold if specified
                    if let threshold = threshold {
                        let similarity = self.distanceToSimilarity(distance)
                        if similarity >= threshold {
                            results.append((emailId, distance))
                        }
                    } else {
                        results.append((emailId, distance))
                    }
                }
            }
            
            return results
        }
    }
    
    /// Search for similar emails with full email records
    /// - Parameters:
    ///   - queryEmbedding: Query vector
    ///   - limit: Maximum number of results
    ///   - threshold: Minimum similarity score
    /// - Returns: Array of (email, similarity) tuples
    public func searchSimilarEmails(
        queryEmbedding: [Float],
        limit: Int = 10,
        threshold: Double = 0.7
    ) async throws -> [(email: EmailRecord, similarity: Double)] {
        let similar = try await searchSimilar(
            queryEmbedding: queryEmbedding,
            limit: limit,
            threshold: threshold
        )
        
        let emailIds = similar.map(\.emailId)
        
        return try await dbQueue.read { db in
            let emails = try EmailRecord
                .filter(emailIds.contains(Column("id")))
                .fetchAll(db)
            
            // Map back to similarity scores
            var results: [(email: EmailRecord, similarity: Double)] = []
            for (emailId, distance) in similar {
                if let email = emails.first(where: { $0.id == emailId }) {
                    let similarity = self.distanceToSimilarity(distance)
                    results.append((email, similarity))
                }
            }
            
            return results
        }
    }
    
    /// Find emails similar to a given email
    /// - Parameters:
    ///   - emailId: Email ID to find similar items for
    ///   - limit: Maximum number of results
    ///   - excludeSelf: Whether to exclude the source email from results
    /// - Returns: Array of similar emails with similarity scores
    public func findSimilarToEmail(
        emailId: String,
        limit: Int = 10,
        excludeSelf: Bool = true
    ) async throws -> [(email: EmailRecord, similarity: Double)] {
        // Get the embedding for the source email
        let embedding = try await getEmbedding(for: emailId)
        
        var results = try await searchSimilarEmails(
            queryEmbedding: embedding,
            limit: excludeSelf ? limit + 1 : limit
        )
        
        if excludeSelf {
            results.removeAll { $0.email.id == emailId }
        }
        
        return Array(results.prefix(limit))
    }
    
    /// Semantic search using text query (requires embedding generation)
    /// - Parameters:
    ///   - text: Search text
    ///   - embedder: Function to convert text to embedding
    ///   - limit: Maximum results
    /// - Returns: Array of similar emails
    public func semanticSearch(
        text: String,
        embedder: (String) async throws -> [Float],
        limit: Int = 10
    ) async throws -> [(email: EmailRecord, similarity: Double)] {
        let embedding = try await embedder(text)
        return try await searchSimilarEmails(
            queryEmbedding: embedding,
            limit: limit,
            threshold: 0.0 // Return all results ranked
        )
    }
    
    // MARK: - Embedding Retrieval
    
    /// Get embedding for an email
    /// - Parameter emailId: Email ID
    /// - Returns: Embedding vector
    public func getEmbedding(for emailId: String) async throws -> [Float] {
        return try await dbQueue.read { db in
            guard let record = try EmailEmbeddingRecord
                .filter(Column("email_id") == emailId)
                .fetchOne(db) else {
                throw VectorStoreError.embeddingNotFound(emailId: emailId)
            }
            
            return record.embedding.toFloatArray()
        }
    }
    
    /// Check if an email has an embedding
    /// - Parameter emailId: Email ID
    /// - Returns: True if embedding exists
    public func hasEmbedding(for emailId: String) async throws -> Bool {
        return try await dbQueue.read { db in
            return try EmailEmbeddingRecord
                .filter(Column("email_id") == emailId)
                .fetchCount(db) > 0
        }
    }
    
    /// Get all embeddings without email records
    /// - Returns: Dictionary of emailId to embedding
    public func getAllEmbeddings() async throws -> [String: [Float]] {
        return try await dbQueue.read { db in
            let records = try EmailEmbeddingRecord.fetchAll(db)
            var result: [String: [Float]] = [:]
            for record in records {
                result[record.emailId] = record.embedding.toFloatArray()
            }
            return result
        }
    }
    
    // MARK: - Deletion
    
    /// Delete embedding for an email
    /// - Parameter emailId: Email ID
    public func deleteEmbedding(for emailId: String) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM vec_emails WHERE email_id = ?", arguments: [emailId])
            try db.execute(sql: "DELETE FROM email_embeddings WHERE email_id = ?", arguments: [emailId])
        }
        
        logger.debug("Deleted embedding for email: \(emailId)")
    }
    
    /// Delete all embeddings
    public func deleteAllEmbeddings() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM vec_emails")
            try db.execute(sql: "DELETE FROM email_embeddings")
        }
        
        logger.info("Deleted all embeddings")
    }
    
    // MARK: - Statistics
    
    /// Get vector store statistics
    /// - Returns: Statistics about stored embeddings
    public func getStatistics() async throws -> VectorStoreStatistics {
        return try await dbQueue.read { db in
            let count = try EmailEmbeddingRecord.fetchCount(db)
            let models = try String.fetchAll(db, sql: "SELECT DISTINCT model_name FROM email_embeddings")
            
            return VectorStoreStatistics(
                totalEmbeddings: count,
                dimensions: self.dimensions,
                models: models
            )
        }
    }
    
    /// Get emails without embeddings
    /// - Parameter limit: Maximum number to return
    /// - Returns: Array of email IDs
    public func getEmailsWithoutEmbeddings(limit: Int = 100) async throws -> [String] {
        return try await dbQueue.read { db in
            return try String.fetchAll(
                db,
                sql: """
                    SELECT e.id FROM emails e
                    LEFT JOIN email_embeddings ee ON e.id = ee.email_id
                    WHERE ee.email_id IS NULL
                    LIMIT ?
                    """,
                arguments: [limit]
            )
        }
    }
    
    // MARK: - Utility
    
    /// Convert distance to similarity score (0.0-1.0)
    /// - Parameter distance: Raw distance from vec0
    /// - Returns: Similarity score
    private func distanceToSimilarity(_ distance: Double) -> Double {
        switch config.metric {
        case .cosine:
            // Cosine distance ranges 0-2, similarity is 1 - distance/2
            return max(0.0, 1.0 - (distance / 2.0))
        case .euclidean:
            // For L2, use exponential decay
            return exp(-distance)
        case .dot:
            // Dot product can be negative, normalize to 0-1
            return (distance + 1.0) / 2.0
        }
    }
    
    /// Rebuild the vector index
    public func rebuildIndex() async throws {
        try await dbQueue.write { db in
            // Re-insert all embeddings into vec0 table
            try db.execute(sql: "DELETE FROM vec_emails")
            
            let records = try EmailEmbeddingRecord.fetchAll(db)
            for record in records {
                let embedding = record.embedding.toFloatArray()
                try self.insertIntoVecTable(db, emailId: record.emailId, embedding: embedding)
            }
        }
        
        logger.info("Rebuilt vector index with current embeddings")
    }
}

// MARK: - Supporting Types

/// Statistics for the vector store
public struct VectorStoreStatistics: Codable {
    public let totalEmbeddings: Int
    public let dimensions: Int
    public let models: [String]
}

/// Vector store errors
public enum VectorStoreError: LocalizedError {
    case dimensionMismatch(expected: Int, actual: Int)
    case embeddingNotFound(emailId: String)
    case extensionNotAvailable
    case invalidEmbedding
    
    public var errorDescription: String? {
        switch self {
        case .dimensionMismatch(let expected, let actual):
            return "Dimension mismatch: expected \(expected), got \(actual)"
        case .embeddingNotFound(let emailId):
            return "Embedding not found for email: \(emailId)"
        case .extensionNotAvailable:
            return "sqlite-vec extension not available"
        case .invalidEmbedding:
            return "Invalid embedding data"
        }
    }
}

// MARK: - Data Extensions

private extension Data {
    func toFloatArray() -> [Float] {
        let count = self.count / MemoryLayout<Float>.size
        return self.withUnsafeBytes { buffer in
            Array(UnsafeBufferPointer(start: buffer.baseAddress?.assumingMemoryBound(to: Float.self), count: count))
        }
    }
    
    init(bytes: [Float], count: Int) {
        self = bytes.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}
