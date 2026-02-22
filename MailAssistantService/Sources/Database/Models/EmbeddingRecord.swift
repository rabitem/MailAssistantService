import Foundation
import GRDB

/// GRDB Record for vector embeddings storage
/// Used for semantic search and similarity matching across different entity types
public struct EmbeddingRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "embeddings"
    
    // MARK: - Primary Key
    public var id: String
    
    // MARK: - Entity Reference
    /// Type of entity this embedding belongs to (email, contact, template, etc.)
    public var entityType: EntityType
    
    /// ID of the entity this embedding represents
    public var entityId: String
    
    // MARK: - Embedding Data
    /// The embedding vector stored as binary data (array of Float32)
    public var vector: Data
    
    /// Number of dimensions in the embedding
    public var dimensions: Int
    
    // MARK: - Model Information
    /// Name/identifier of the model used to generate this embedding
    public var modelName: String
    
    /// Version of the model
    public var modelVersion: String?
    
    // MARK: - Content Hash
    /// Hash of the original content (for invalidation detection)
    public var contentHash: String?
    
    // MARK: - Metadata
    /// Optional metadata about the embedding (JSON)
    public var metadata: String?
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Enums
    
    public enum EntityType: String, Codable, DatabaseValueConvertible, CaseIterable {
        case email = "email"
        case contact = "contact"
        case template = "template"
        case profile = "profile"
        case document = "document"
        case custom = "custom"
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case entityType = "entity_type"
        case entityId = "entity_id"
        case vector
        case dimensions
        case modelName = "model_name"
        case modelVersion = "model_version"
        case contentHash = "content_hash"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        entityType: EntityType,
        entityId: String,
        vector: [Float],
        modelName: String,
        modelVersion: String? = nil,
        contentHash: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.vector = Data(bytes: vector, count: vector.count * MemoryLayout<Float>.size)
        self.dimensions = vector.count
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.contentHash = contentHash
        self.metadata = metadata.flatMap { dict -> String? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Initialize with Data directly
    public init(
        id: String = UUID().uuidString,
        entityType: EntityType,
        entityId: String,
        vectorData: Data,
        dimensions: Int,
        modelName: String,
        modelVersion: String? = nil,
        contentHash: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.vector = vectorData
        self.dimensions = dimensions
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.contentHash = contentHash
        self.metadata = metadata.flatMap { dict -> String? in
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - PersistableRecord
    
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        // Row inserted successfully, timestamps already set in init
    }
    
    // MARK: - Vector Access
    
    /// Get the embedding as an array of Floats
    public func getVector() -> [Float] {
        return vector.toFloatArray()
    }
    
    /// Get the embedding as a JSON string (for sqlite-vec)
    public func getVectorJSON() -> String {
        let floats = getVector()
        return "[" + floats.map { String($0) }.joined(separator: ",") + "]"
    }
    
    // MARK: - Metadata Access
    
    public func getMetadata() -> [String: Any]? {
        guard let metadata = metadata,
              let data = metadata.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    // MARK: - Similarity Computation
    
    /// Compute cosine similarity with another embedding
    public func cosineSimilarity(with other: EmbeddingRecord) -> Double {
        let v1 = getVector()
        let v2 = other.getVector()
        
        guard v1.count == v2.count else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var norm1: Float = 0.0
        var norm2: Float = 0.0
        
        for i in 0..<v1.count {
            dotProduct += v1[i] * v2[i]
            norm1 += v1[i] * v1[i]
            norm2 += v2[i] * v2[i]
        }
        
        guard norm1 > 0 && norm2 > 0 else { return 0.0 }
        
        return Double(dotProduct / (sqrt(norm1) * sqrt(norm2)))
    }
    
    /// Compute Euclidean distance with another embedding
    public func euclideanDistance(to other: EmbeddingRecord) -> Double {
        let v1 = getVector()
        let v2 = other.getVector()
        
        guard v1.count == v2.count else { return Double.infinity }
        
        var sum: Float = 0.0
        for i in 0..<v1.count {
            let diff = v1[i] - v2[i]
            sum += diff * diff
        }
        
        return Double(sqrt(sum))
    }
    
    /// Compute dot product with another embedding
    public func dotProduct(with other: EmbeddingRecord) -> Double {
        let v1 = getVector()
        let v2 = other.getVector()
        
        guard v1.count == v2.count else { return 0.0 }
        
        var result: Float = 0.0
        for i in 0..<v1.count {
            result += v1[i] * v2[i]
        }
        
        return Double(result)
    }
}

// MARK: - Query Extensions

extension EmbeddingRecord {
    /// Query by entity type
    public static func forEntityType(_ type: EntityType) -> QueryInterfaceRequest<EmbeddingRecord> {
        filter(Column("entity_type") == type.rawValue)
    }
    
    /// Query by entity ID
    public static func forEntity(_ entityId: String, type: EntityType? = nil) -> QueryInterfaceRequest<EmbeddingRecord> {
        var query = filter(Column("entity_id") == entityId)
        if let type = type {
            query = query.filter(Column("entity_type") == type.rawValue)
        }
        return query
    }
    
    /// Query by model name
    public static func forModel(_ modelName: String) -> QueryInterfaceRequest<EmbeddingRecord> {
        filter(Column("model_name") == modelName)
    }
    
    /// Query by dimensions
    public static func withDimensions(_ dimensions: Int) -> QueryInterfaceRequest<EmbeddingRecord> {
        filter(Column("dimensions") == dimensions)
    }
    
    /// Query by content hash
    public static func withContentHash(_ hash: String) -> QueryInterfaceRequest<EmbeddingRecord> {
        filter(Column("content_hash") == hash)
    }
    
    /// Query recent embeddings
    public static func recent(limit: Int = 100) -> QueryInterfaceRequest<EmbeddingRecord> {
        order(Column("created_at").desc).limit(limit)
    }
    
    /// Query embeddings needing update (older than date)
    public static func updatedBefore(_ date: Date) -> QueryInterfaceRequest<EmbeddingRecord> {
        filter(Column("updated_at") < date)
    }
}

// MARK: - Batch Operations

extension EmbeddingRecord {
    /// Insert or update embedding (upsert)
    public static func upsert(
        _ db: Database,
        entityType: EntityType,
        entityId: String,
        vector: [Float],
        modelName: String,
        modelVersion: String? = nil
    ) throws {
        let record = EmbeddingRecord(
            entityType: entityType,
            entityId: entityId,
            vector: vector,
            modelName: modelName,
            modelVersion: modelVersion
        )
        try record.insert(db, onConflict: .replace)
    }
    
    /// Delete embeddings for an entity
    public static func deleteForEntity(
        _ db: Database,
        entityId: String,
        type: EntityType? = nil
    ) throws {
        var query: String = "DELETE FROM embeddings WHERE entity_id = ?"
        var arguments: [DatabaseValueConvertible] = [entityId]
        
        if let type = type {
            query += " AND entity_type = ?"
            arguments.append(type.rawValue)
        }
        
        try db.execute(sql: query, arguments: StatementArguments(arguments))
    }
    
    /// Count embeddings by entity type
    public static func countByEntityType(_ db: Database) throws -> [EntityType: Int] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT entity_type, COUNT(*) as count 
            FROM embeddings 
            GROUP BY entity_type
            """)
        
        var result: [EntityType: Int] = [:]
        for row in rows {
            if let typeString = row["entity_type"] as String?,
               let type = EntityType(rawValue: typeString),
               let count = row["count"] as Int? {
                result[type] = count
            }
        }
        return result
    }
}

// MARK: - Data Extension

private extension Data {
    func toFloatArray() -> [Float] {
        let count = self.count / MemoryLayout<Float>.size
        return self.withUnsafeBytes { buffer in
            Array(UnsafeBufferPointer(
                start: buffer.baseAddress?.assumingMemoryBound(to: Float.self),
                count: count
            ))
        }
    }
    
    init(bytes: [Float], count: Int) {
        self = bytes.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}

// MARK: - Embedding Statistics

/// Statistics for embeddings in the database
public struct EmbeddingStatistics: Codable {
    public let totalCount: Int
    public let byEntityType: [String: Int]
    public let byModel: [String: Int]
    public let averageDimensions: Int
    
    public var description: String {
        """
        Embedding Statistics:
        - Total Embeddings: \(totalCount)
        - By Entity Type: \(byEntityType)
        - By Model: \(byModel)
        - Average Dimensions: \(averageDimensions)
        """
    }
}

// MARK: - Embedding Collection

/// Helper for batch embedding operations
public struct EmbeddingCollection {
    private var embeddings: [EmbeddingRecord] = []
    
    public init() {}
    
    public mutating func add(_ embedding: EmbeddingRecord) {
        embeddings.append(embedding)
    }
    
    public mutating func add(
        entityType: EmbeddingRecord.EntityType,
        entityId: String,
        vector: [Float],
        modelName: String
    ) {
        let embedding = EmbeddingRecord(
            entityType: entityType,
            entityId: entityId,
            vector: vector,
            modelName: modelName
        )
        embeddings.append(embedding)
    }
    
    /// Save all embeddings to database
    public func saveAll(_ db: Database) throws {
        for embedding in embeddings {
            try embedding.insert(db, onConflict: .replace)
        }
    }
    
    /// Get all embeddings
    public func all() -> [EmbeddingRecord] {
        return embeddings
    }
    
    /// Count of embeddings
    public var count: Int {
        return embeddings.count
    }
    
    /// Check if empty
    public var isEmpty: Bool {
        return embeddings.isEmpty
    }
}
