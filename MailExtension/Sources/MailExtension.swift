//
//  MailExtension.swift
//  MailExtension
//

import MailKit
import Cocoa

/// Main entry point for the Kimi Mail Assistant Mail Extension
@main
class MailExtension: MEExtension {
    
    // MARK: - Properties
    
    private let composeHandler = ComposeSessionHandler()
    private let messageHandler = MessageActionHandler()
    private let extensionHandler = ExtensionSessionHandler()
    
    // MARK: - Singleton
    
    /// Shared instance for accessing from other classes
    /// Note: Will be nil until the extension is initialized by Mail
    private(set) static var shared: MailExtension?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        MailExtension.shared = self
        
        // Register keyboard shortcuts
        KeyboardShortcutManager.shared.registerShortcuts()
        
        // Inject menu items
        MenuInjector.shared.injectMenu()
        
        print("[MailExtension] Extension initialized")
    }
    
    deinit {
        KeyboardShortcutManager.shared.unregisterShortcuts()
        MenuInjector.shared.removeMenu()
    }
    
    // MARK: - MEExtension Overrides
    
    /// Returns the handler for compose sessions
    override func handlerForComposeSession(_ session: MEComposeSession) -> MEComposeSessionHandler {
        print("[MailExtension] Creating compose handler for session: \(session.identifier)")
        return composeHandler
    }
    
    /// Returns the handler for message actions
    override func handlerForMessageActions() -> MEMessageActionHandler {
        return messageHandler
    }
    
    /// Returns the handler for extension sessions
    override func handler(for session: MEExtensionSession) -> MEExtensionSessionHandler {
        return extensionHandler
    }
    
    // MARK: - Lifecycle
    
    /// Called when the extension needs to begin authorization
    override func beginAuthorization(completion: @escaping (Result<MEDirectMessageAuthorization, Error>) -> Void) {
        print("[MailExtension] Beginning authorization")
        
        // Create authorization with required capabilities
        let authorization = MEDirectMessageAuthorization()
        completion(.success(authorization))
    }
    
    /// Called when the extension is about to terminate
    override func terminate() {
        print("[MailExtension] Extension terminating")
        
        // Clean up resources
        composeHandler.cleanup()
        extensionHandler.cleanup()
        
        KeyboardShortcutManager.shared.unregisterShortcuts()
        MenuInjector.shared.removeMenu()
        
        super.terminate()
    }
}

// MARK: - Extension Session Handler

class ExtensionSessionHandler: NSObject, MEExtensionSessionHandler {
    
    private var activeSessions: Set<MEExtensionSession> = []
    
    func sessionDidBegin(_ session: MEExtensionSession) {
        print("[ExtensionSessionHandler] Session began: \(session.identifier)")
        activeSessions.insert(session)
    }
    
    func sessionDidEnd(_ session: MEExtensionSession) {
        print("[ExtensionSessionHandler] Session ended: \(session.identifier)")
        activeSessions.remove(session)
    }
    
    func cleanup() {
        activeSessions.removeAll()
    }
}

// MARK: - Message Action Handler

class MessageActionHandler: NSObject, MEMessageActionHandler {
    
    private let xpcService: XPCServiceProtocol
    
    override init() {
        self.xpcService = XPCServiceConnection.shared.getService() ?? MockXPCService.shared
        super.init()
    }
    
    func decideAction(for message: MEMessage, completion: @escaping (MEMessageActionDecision) -> Void) {
        let actions = defaultActions(for: message)
        completion(.invokeActions(actions))
    }
    
    func decideActionForMessages(
        identifiers: [MEMessageIdentifier],
        completion: @escaping (MEMessageActionDecision) -> Void
    ) {
        completion(.invokeActions([]))
    }
    
    private func defaultActions(for message: MEMessage) -> [MEMessageAction] {
        var actions: [MEMessageAction] = []
        
        // AI-powered actions
        actions.append(.custom(
            title: "Summarize",
            identifier: "com.rabitem.MailAssistant.summarize"
        ))
        
        actions.append(.custom(
            title: "Suggest Reply",
            identifier: "com.rabitem.MailAssistant.suggestReply"
        ))
        
        actions.append(.custom(
            title: "Analyze Tone",
            identifier: "com.rabitem.MailAssistant.analyzeTone"
        ))
        
        actions.append(.custom(
            title: "Quick Reply",
            identifier: "com.rabitem.MailAssistant.quickReply"
        ))
        
        return actions
    }
    
    func performAction(_ action: MEMessageAction, for message: MEMessage, completion: @escaping (MEMessageActionResult) -> Void) {
        print("[MessageActionHandler] Performing action: \(action.identifier)")
        
        switch action.identifier {
        case "com.rabitem.MailAssistant.summarize":
            performSummarize(message: message, completion: completion)
        case "com.rabitem.MailAssistant.suggestReply":
            performSuggestReply(message: message, completion: completion)
        case "com.rabitem.MailAssistant.analyzeTone":
            performAnalyzeTone(message: message, completion: completion)
        case "com.rabitem.MailAssistant.quickReply":
            performQuickReply(message: message, completion: completion)
        default:
            completion(.success)
        }
    }
    
    // MARK: - Action Implementations
    
    private func performSummarize(message: MEMessage, completion: @escaping (MEMessageActionResult) -> Void) {
        let content = EmailContent(
            subject: message.subject,
            body: message.plainTextBody ?? "",
            sender: message.sender?.formatted ?? "",
            recipients: message.toAddresses.map { $0.formatted },
            threadMessages: nil,
            attachments: nil
        )
        
        xpcService.analyzeTone(content: content) { result in
            switch result {
            case .success:
                completion(.success)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performSuggestReply(message: MEMessage, completion: @escaping (MEMessageActionResult) -> Void) {
        // This would open a compose window with suggestions
        NotificationCenter.default.post(
            name: .suggestReplyForMessage,
            object: nil,
            userInfo: ["message": message]
        )
        completion(.success)
    }
    
    private func performAnalyzeTone(message: MEMessage, completion: @escaping (MEMessageActionResult) -> Void) {
        let content = EmailContent(
            subject: message.subject,
            body: message.plainTextBody ?? "",
            sender: message.sender?.formatted ?? "",
            recipients: message.toAddresses.map { $0.formatted },
            threadMessages: nil,
            attachments: nil
        )
        
        xpcService.analyzeTone(content: content) { result in
            switch result {
            case .success(let analysis):
                // Post notification to show analysis
                NotificationCenter.default.post(
                    name: .showToneAnalysisResult,
                    object: nil,
                    userInfo: ["analysis": analysis]
                )
                completion(.success)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performQuickReply(message: MEMessage, completion: @escaping (MEMessageActionResult) -> Void) {
        // Generate a quick reply and open compose
        let request = GenerationRequest(
            emailContent: EmailContent(
                subject: message.subject,
                body: message.plainTextBody ?? "",
                sender: message.sender?.formatted ?? "",
                recipients: message.toAddresses.map { $0.formatted },
                threadMessages: nil,
                attachments: nil
            ),
            tone: .professional,
            length: .brief,
            styleProfile: nil,
            previousResponses: nil,
            context: .init(
                isReply: true,
                isForward: false,
                threadCount: 1,
                urgencyIndicators: [],
                actionItems: []
            )
        )
        
        xpcService.generateResponses(request: request) { result in
            switch result {
            case .success(let responses):
                if let first = responses.first {
                    NotificationCenter.default.post(
                        name: .quickReplyGenerated,
                        object: nil,
                        userInfo: ["response": first, "originalMessage": message]
                    )
                }
                completion(.success)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let suggestReplyForMessage = Notification.Name("com.rabitem.MailAssistant.suggestReplyForMessage")
    static let showToneAnalysisResult = Notification.Name("com.rabitem.MailAssistant.showToneAnalysisResult")
    static let quickReplyGenerated = Notification.Name("com.rabitem.MailAssistant.quickReplyGenerated")
}
