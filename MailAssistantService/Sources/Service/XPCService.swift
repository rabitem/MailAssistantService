//
//  XPCService.swift
//  MailAssistantService
//
//  Implementation of XPC interface - bridge between XPC and internal services
//

import Foundation
import os.log

// MARK: - XPC Service Implementation

/// Main service implementation that handles XPC requests
class XPCService: NSObject, MailAssistantServiceProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.kimimail.assistant.service", category: "XPCService")
    private let responseGenerator: ResponseGenerator
    private let emailSearch: EmailSearchService
    private let writingProfile: WritingProfileService
    private let pluginManager: PluginManager
    private let backgroundTaskManager: BackgroundTaskManager
    private let lifecycleManager: LifecycleManager
    
    // MARK: - Initialization
    
    override init() {
        self.lifecycleManager = LifecycleManager.shared
        self.responseGenerator = ResponseGenerator()
        self.emailSearch = EmailSearchService()
        self.writingProfile = WritingProfileService()
        self.pluginManager = PluginManager.shared
        self.backgroundTaskManager = BackgroundTaskManager.shared
        
        super.init()
        
        logger.info("🚀 XPCService initialized")
    }
    
    // MARK: - Response Generation
    
    func generateResponse(for emailID: String, style: String, completion: @escaping (String?, Error?) -> Void) {
        logger.info("📧 Generating response for email: \(emailID, privacy: .private), style: \(style)")
        
        // Validate inputs
        guard !emailID.isEmpty else {
            completion(nil, XPCServiceError.invalidEmailID)
            return
        }
        
        // Run in background to avoid blocking XPC
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil, XPCServiceError.serviceNotAvailable)
                return
            }
            
            self.responseGenerator.generateResponse(
                forEmailID: emailID,
                style: style
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        self.logger.info("✅ Response generated successfully")
                        completion(response, nil)
                    case .failure(let error):
                        self.logger.error("❌ Response generation failed: \(error.localizedDescription)")
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    func generateQuickReply(for emailID: String, tone: String?, completion: @escaping (String?, Error?) -> Void) {
        logger.info("⚡ Generating quick reply for email: \(emailID, privacy: .private)")
        
        let effectiveTone = tone ?? "neutral"
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil, XPCServiceError.serviceNotAvailable)
                return
            }
            
            self.responseGenerator.generateQuickReply(
                forEmailID: emailID,
                tone: effectiveTone
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let reply):
                        completion(reply, nil)
                    case .failure(let error):
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    // MARK: - Writing Profile
    
    func getWritingProfile(completion: @escaping (Data?, Error?) -> Void) {
        logger.info("📊 Getting writing profile")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil, XPCServiceError.serviceNotAvailable)
                return
            }
            
            self.writingProfile.getCurrentProfile { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let profile):
                        do {
                            let encoder = JSONEncoder()
                            encoder.dateEncodingStrategy = .iso8601
                            let data = try encoder.encode(profile)
                            completion(data, nil)
                        } catch {
                            completion(nil, XPCServiceError.internalError)
                        }
                    case .failure(let error):
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    func updateWritingProfile(with sampleIDs: [String], completion: @escaping (Bool, Error?) -> Void) {
        logger.info("🔄 Updating writing profile with \(sampleIDs.count) samples")
        
        guard !sampleIDs.isEmpty else {
            completion(false, XPCServiceError.invalidRequest)
            return
        }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                completion(false, XPCServiceError.serviceNotAvailable)
                return
            }
            
            self.writingProfile.updateProfile(with: sampleIDs) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, nil)
                    case .failure(let error):
                        completion(false, error)
                    }
                }
            }
        }
    }
    
    // MARK: - Email Search
    
    func searchEmails(query: String, completion: @escaping ([Data]?, Error?) -> Void) {
        logger.info("🔍 Searching emails with query: \(query, privacy: .private)")
        
        guard !query.isEmpty else {
            completion([], nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil, XPCServiceError.serviceNotAvailable)
                return
            }
            
            self.emailSearch.search(query: query) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let results):
                        do {
                            let encoder = JSONEncoder()
                            encoder.dateEncodingStrategy = .iso8601
                            let dataArray = try results.map { try encoder.encode($0) }
                            completion(dataArray, nil)
                        } catch {
                            completion(nil, XPCServiceError.internalError)
                        }
                    case .failure(let error):
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    func getThreadContext(for emailID: String, completion: @escaping (Data?, Error?) -> Void) {
        logger.info("🧵 Getting thread context for email: \(emailID, privacy: .private)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil, XPCServiceError.serviceNotAvailable)
                return
            }
            
            self.emailSearch.getThreadContext(for: emailID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let thread):
                        do {
                            let encoder = JSONEncoder()
                            encoder.dateEncodingStrategy = .iso8601
                            let data = try encoder.encode(thread)
                            completion(data, nil)
                        } catch {
                            completion(nil, XPCServiceError.internalError)
                        }
                    case .failure(let error):
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    // MARK: - Plugin Management
    
    func enablePlugin(id: String, completion: @escaping (Bool, Error?) -> Void) {
        logger.info("🔌 Enabling plugin: \(id)")
        
        pluginManager.enablePlugin(id: id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(true, nil)
                case .failure(let error):
                    completion(false, error)
                }
            }
        }
    }
    
    func disablePlugin(id: String, completion: @escaping (Bool, Error?) -> Void) {
        logger.info("🔌 Disabling plugin: \(id)")
        
        pluginManager.disablePlugin(id: id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(true, nil)
                case .failure(let error):
                    completion(false, error)
                }
            }
        }
    }
    
    func getPluginStatus(completion: @escaping (Data?, Error?) -> Void) {
        logger.info("📋 Getting plugin status")
        
        let statuses = pluginManager.getAllPluginStatuses()
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(statuses)
            completion(data, nil)
        } catch {
            completion(nil, XPCServiceError.internalError)
        }
    }
    
    func getAvailablePlugins(completion: @escaping (Data?, Error?) -> Void) {
        logger.info("📋 Getting available plugins")
        
        let plugins = pluginManager.getAvailablePlugins()
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(plugins)
            completion(data, nil)
        } catch {
            completion(nil, XPCServiceError.internalError)
        }
    }
    
    // MARK: - Service Health & Info
    
    func getServiceInfo(completion: @escaping (Data?, Error?) -> Void) {
        logger.info("ℹ️ Getting service info")
        
        let info = lifecycleManager.currentServiceInfo
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(info)
            completion(data, nil)
        } catch {
            completion(nil, XPCServiceError.internalError)
        }
    }
    
    func ping(completion: @escaping (Bool) -> Void) {
        logger.debug("🏓 Ping received")
        completion(true)
    }
}

// MARK: - Placeholder Service Classes

/// Placeholder for response generation service
class ResponseGenerator {
    func generateResponse(forEmailID: String, style: String, completion: @escaping (Result<String, Error>) -> Void) {
        // TODO: Implement actual response generation with AI
        completion(.success("Thank you for your email. I'll get back to you soon."))
    }
    
    func generateQuickReply(forEmailID: String, tone: String, completion: @escaping (Result<String, Error>) -> Void) {
        // TODO: Implement quick reply generation
        completion(.success("Got it, thanks!"))
    }
}

/// Placeholder for email search service
class EmailSearchService {
    func search(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        // TODO: Implement actual search
        completion(.success([]))
    }
    
    func getThreadContext(for emailID: String, completion: @escaping (Result<ThreadContext, Error>) -> Void) {
        // TODO: Implement thread context retrieval
        completion(.success(ThreadContext(threadID: "", emails: [])))
    }
}

/// Placeholder for writing profile service
class WritingProfileService {
    func getCurrentProfile(completion: @escaping (Result<WritingProfileData, Error>) -> Void) {
        // TODO: Implement profile retrieval
        let profile = WritingProfileData(
            profileID: "default",
            name: "Default Profile",
            createdAt: Date(),
            updatedAt: Date(),
            sampleCount: 0,
            characteristics: [:],
            commonPhrases: [],
            averageResponseLength: 150,
            preferredGreetings: ["Hi", "Hello"],
            preferredSignoffs: ["Best regards", "Thanks"]
        )
        completion(.success(profile))
    }
    
    func updateProfile(with sampleIDs: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement profile update
        completion(.success(()))
    }
}

/// Thread context structure
struct ThreadContext: Codable {
    let threadID: String
    let emails: [EmailInThread]
}

struct EmailInThread: Codable {
    let id: String
    let subject: String
    let sender: String
    let date: Date
    let body: String
    let isOutgoing: Bool
}
