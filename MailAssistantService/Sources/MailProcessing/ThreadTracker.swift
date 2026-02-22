//
//  ThreadTracker.swift
//  MailAssistantService
//
//  Track email threads and build conversation history
//

import Foundation
import os.log

// MARK: - Thread Tracker

/// Manages email thread tracking and conversation history building
class ThreadTracker {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.kimimail.assistant.service", category: "ThreadTracker")
    private let databaseQueue = DispatchQueue(label: "com.kimimail.threads", qos: .utility)
    
    /// In-memory cache of thread mappings
    private var threadCache: [String: String] = [:] // messageID -> threadID
    private let cacheLock = NSLock()
    
    /// Statistics tracking
    private(set) var statistics = ThreadStatistics()
    
    // MARK: - Initialization
    
    init() {
        loadThreadCache()
    }
    
    // MARK: - Thread Operations
    
    /// Updates all thread associations
    func updateThreads(completion: @escaping (Result<Int, ThreadError>) -> Void) {
        databaseQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.serviceUnavailable))
                return
            }
            
            self.logger.info("🧵 Starting thread update...")
            
            do {
                let count = try self.performThreadUpdate()
                self.statistics.recordUpdate(threadsProcessed: count)
                
                self.logger.info("✅ Thread update complete: \(count) threads processed")
                completion(.success(count))
                
            } catch let error as ThreadError {
                self.statistics.recordError(error)
                self.logger.error("❌ Thread update failed: \(error.localizedDescription)")
                completion(.failure(error))
            } catch {
                let threadError = ThreadError.unknown(error)
                self.statistics.recordError(threadError)
                completion(.failure(threadError))
            }
        }
    }
    
    /// Gets the thread ID for a specific email
    func getThreadID(for emailID: String) -> String? {
        cacheLock.lock()
        let threadID = threadCache[emailID]
        cacheLock.unlock()
        return threadID
    }
    
    /// Gets all emails in a thread
    func getThreadEmails(threadID: String, completion: @escaping (Result<[ThreadEmail], ThreadError>) -> Void) {
        databaseQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.serviceUnavailable))
                return
            }
            
            do {
                let emails = try self.fetchEmailsInThread(threadID: threadID)
                completion(.success(emails))
            } catch {
                completion(.failure(.databaseError))
            }
        }
    }
    
    /// Builds conversation context for a thread (for AI response generation)
    func buildConversationContext(for threadID: String, maxEmails: Int = 10) -> ConversationContext? {
        // Fetch thread emails
        var emails: [ThreadEmail] = []
        
        let semaphore = DispatchSemaphore(value: 0)
        getThreadEmails(threadID: threadID) { result in
            if case .success(let fetched) = result {
                emails = fetched
            }
            semaphore.signal()
        }
        semaphore.wait()
        
        guard !emails.isEmpty else { return nil }
        
        // Sort by date
        emails.sort { $0.date < $1.date }
        
        // Take the most recent emails up to maxEmails
        let recentEmails = emails.suffix(maxEmails)
        
        // Build conversation context
        var messages: [ConversationMessage] = []
        
        for email in recentEmails {
            let role: ConversationRole = email.isOutgoing ? .assistant : .user
            messages.append(ConversationMessage(
                role: role,
                sender: email.sender.displayString,
                content: email.body,
                timestamp: email.date
            ))
        }
        
        return ConversationContext(
            threadID: threadID,
            subject: emails.first?.subject ?? "",
            participants: Array(Set(emails.flatMap { [$0.sender] + $0.recipients })),
            messages: messages,
            totalMessageCount: emails.count
        )
    }
    
    /// Assigns a thread ID to a newly imported email
    func assignThread(to emailID: String, subject: String, references: [String], inReplyTo: String?) -> String {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // Check if this email is a reply to an existing thread
        if let inReplyTo = inReplyTo,
           let existingThreadID = threadCache[inReplyTo] {
            threadCache[emailID] = existingThreadID
            return existingThreadID
        }
        
        // Check references header
        for reference in references {
            if let existingThreadID = threadCache[reference] {
                threadCache[emailID] = existingThreadID
                return existingThreadID
            }
        }
        
        // Check for subject-based threading (for emails without References)
        let normalizedSubject = normalizeSubject(subject)
        if !normalizedSubject.isEmpty {
            // Look for existing thread with same normalized subject
            for (msgID, threadID) in threadCache {
                // This would need to fetch the subject from the database
                // For now, create a new thread
                _ = msgID
                _ = threadID
            }
        }
        
        // Create a new thread
        let newThreadID = generateThreadID()
        threadCache[emailID] = newThreadID
        return newThreadID
    }
    
    /// Merges two threads (when we discover they're actually the same conversation)
    func mergeThreads(primaryID: String, secondaryID: String, completion: @escaping (Result<Void, ThreadError>) -> Void) {
        databaseQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.serviceUnavailable))
                return
            }
            
            guard primaryID != secondaryID else {
                completion(.success(()))
                return
            }
            
            self.logger.info("🔄 Merging thread \(secondaryID) into \(primaryID)")
            
            do {
                try self.performThreadMerge(primary: primaryID, secondary: secondaryID)
                
                // Update cache
                self.cacheLock.lock()
                for (msgID, threadID) in self.threadCache {
                    if threadID == secondaryID {
                        self.threadCache[msgID] = primaryID
                    }
                }
                self.cacheLock.unlock()
                
                self.logger.info("✅ Thread merge complete")
                completion(.success(()))
                
            } catch {
                completion(.failure(.databaseError))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performThreadUpdate() throws -> Int {
        // This would typically:
        // 1. Fetch all emails without thread IDs
        // 2. Group them by conversation
        // 3. Assign thread IDs
        // 4. Update the database
        
        // Placeholder implementation
        let unthreadedEmails = try fetchUnthreadedEmails()
        var processedCount = 0
        
        for email in unthreadedEmails {
            let threadID = assignThread(
                to: email.id,
                subject: email.subject,
                references: email.references,
                inReplyTo: email.inReplyTo
            )
            
            try updateEmailThreadID(emailID: email.id, threadID: threadID)
            processedCount += 1
            
            if processedCount % 100 == 0 {
                saveThreadCache()
            }
        }
        
        saveThreadCache()
        return processedCount
    }
    
    private func fetchUnthreadedEmails() throws -> [EmailThreadInfo] {
        // TODO: Fetch from database
        return []
    }
    
    private func fetchEmailsInThread(threadID: String) throws -> [ThreadEmail] {
        // TODO: Fetch from database
        return []
    }
    
    private func updateEmailThreadID(emailID: String, threadID: String) throws {
        // TODO: Update in database
        logger.debug("Assigning email \(emailID) to thread \(threadID)")
    }
    
    private func performThreadMerge(primary: String, secondary: String) throws {
        // TODO: Update database to merge threads
        logger.debug("Merging thread \(secondary) into \(primary)")
    }
    
    private func generateThreadID() -> String {
        return "thread-\(UUID().uuidString)"
    }
    
    private func normalizeSubject(_ subject: String) -> String {
        var normalized = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove Re:, Fwd:, FW: prefixes
        let prefixes = ["Re:", "RE:", "Fwd:", "FWD:", "FW:", "Fw:"]
        var changed = true
        
        while changed {
            changed = false
            for prefix in prefixes {
                if normalized.hasPrefix(prefix) {
                    normalized = String(normalized.dropFirst(prefix.count))
                        .trimmingCharacters(in: .whitespaces)
                    changed = true
                    break
                }
            }
        }
        
        return normalized
    }
    
    // MARK: - Cache Management
    
    private func loadThreadCache() {
        // TODO: Load from persistent storage
        logger.debug("Loading thread cache...")
    }
    
    private func saveThreadCache() {
        // TODO: Save to persistent storage
        logger.debug("Saving thread cache...")
    }
    
    /// Clears the in-memory thread cache
    func clearCache() {
        cacheLock.lock()
        threadCache.removeAll()
        cacheLock.unlock()
        logger.info("Thread cache cleared")
    }
    
    /// Returns cache statistics
    func getCacheStats() -> (size: Int, hitRate: Double) {
        cacheLock.lock()
        let size = threadCache.count
        cacheLock.unlock()
        
        // Calculate hit rate based on statistics
        let hitRate = statistics.cacheHitRate
        
        return (size, hitRate)
    }
}

// MARK: - Supporting Types

enum ThreadError: Error, LocalizedError {
    case serviceUnavailable
    case databaseError
    case threadNotFound
    case invalidThreadID
    case mergeFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Thread tracking service is unavailable"
        case .databaseError:
            return "A database error occurred"
        case .threadNotFound:
            return "Thread not found"
        case .invalidThreadID:
            return "Invalid thread ID"
        case .mergeFailed:
            return "Failed to merge threads"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

struct EmailThreadInfo {
    let id: String
    let subject: String
    let references: [String]
    let inReplyTo: String?
}

struct ThreadEmail: Codable {
    let id: String
    let subject: String
    let sender: EmailAddress
    let recipients: [EmailAddress]
    let date: Date
    let body: String
    let isOutgoing: Bool
}

struct ConversationContext: Codable {
    let threadID: String
    let subject: String
    let participants: [EmailAddress]
    let messages: [ConversationMessage]
    let totalMessageCount: Int
}

struct ConversationMessage: Codable {
    let role: ConversationRole
    let sender: String
    let content: String
    let timestamp: Date
}

enum ConversationRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

struct ThreadStatistics {
    private(set) var totalThreads: Int = 0
    private(set) var totalEmails: Int = 0
    private(set) var updateCount: Int = 0
    private(set) var errorCount: Int = 0
    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    private(set) var lastUpdateTime: Date?
    
    var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0 }
        return Double(cacheHits) / Double(total)
    }
    
    mutating func recordUpdate(threadsProcessed: Int) {
        updateCount += 1
        totalThreads += threadsProcessed
        lastUpdateTime = Date()
    }
    
    mutating func recordError(_ error: ThreadError) {
        errorCount += 1
        _ = error
    }
    
    mutating func recordCacheHit() {
        cacheHits += 1
    }
    
    mutating func recordCacheMiss() {
        cacheMisses += 1
    }
}

// MARK: - Thread Analysis

extension ThreadTracker {
    
    /// Analyzes a thread to extract useful information
    func analyzeThread(threadID: String) -> ThreadAnalysis? {
        var emails: [ThreadEmail] = []
        
        let semaphore = DispatchSemaphore(value: 0)
        getThreadEmails(threadID: threadID) { result in
            if case .success(let fetched) = result {
                emails = fetched
            }
            semaphore.signal()
        }
        semaphore.wait()
        
        guard !emails.isEmpty else { return nil }
        
        emails.sort { $0.date < $1.date }
        
        let firstEmail = emails.first!
        let lastEmail = emails.last!
        
        // Calculate response times
        var responseTimes: [TimeInterval] = []
        for i in 1..<emails.count {
            let responseTime = emails[i].date.timeIntervalSince(emails[i-1].date)
            responseTimes.append(responseTime)
        }
        
        let avgResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        
        // Count unique participants
        var allParticipants = Set<String>()
        for email in emails {
            allParticipants.insert(email.sender.email)
            for recipient in email.recipients {
                allParticipants.insert(recipient.email)
            }
        }
        
        return ThreadAnalysis(
            threadID: threadID,
            emailCount: emails.count,
            duration: lastEmail.date.timeIntervalSince(firstEmail.date),
            participantCount: allParticipants.count,
            averageResponseTime: avgResponseTime,
            isResolved: determineIfResolved(emails: emails),
            lastActivity: lastEmail.date,
            subject: firstEmail.subject
        )
    }
    
    private func determineIfResolved(emails: [ThreadEmail]) -> Bool {
        // Heuristic: thread is resolved if the last email is outgoing and older than 7 days
        // or if it contains certain keywords
        guard let lastEmail = emails.last else { return false }
        
        if lastEmail.isOutgoing {
            let daysSinceLastActivity = Date().timeIntervalSince(lastEmail.date) / 86400
            if daysSinceLastActivity > 7 {
                return true
            }
        }
        
        // Check for resolution keywords in last message
        let resolutionKeywords = ["resolved", "closed", "completed", "done", "thank", "thanks"]
        let lowerBody = lastEmail.body.lowercased()
        
        return resolutionKeywords.contains { lowerBody.contains($0) }
    }
}

struct ThreadAnalysis {
    let threadID: String
    let emailCount: Int
    let duration: TimeInterval
    let participantCount: Int
    let averageResponseTime: TimeInterval
    let isResolved: Bool
    let lastActivity: Date
    let subject: String
    
    var formattedDuration: String {
        let days = Int(duration / 86400)
        if days > 0 {
            return "\(days)d"
        }
        let hours = Int(duration / 3600)
        if hours > 0 {
            return "\(hours)h"
        }
        let minutes = Int(duration / 60)
        return "\(minutes)m"
    }
    
    var formattedResponseTime: String {
        let hours = Int(averageResponseTime / 3600)
        if hours > 24 {
            let days = hours / 24
            return "\(days)d"
        }
        return "\(hours)h"
    }
}
