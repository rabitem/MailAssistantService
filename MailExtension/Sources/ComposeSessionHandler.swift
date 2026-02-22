//
//  ComposeSessionHandler.swift
//  MailExtension
//

import MailKit
import Cocoa
import SwiftUI

/// Handles compose sessions for providing AI-powered writing assistance
class ComposeSessionHandler: NSObject, MEComposeSessionHandler {
    
    // MARK: - Properties
    
    private var activeSessions: [String: ComposeSessionContext] = [:]
    private let xpcService: XPCServiceProtocol
    private let suggestionViewModel: SuggestionViewModel
    private let quickActionsViewModel: QuickActionsViewModel
    
    // MARK: - Initialization
    
    override init() {
        self.xpcService = XPCServiceConnection.shared.getService() ?? MockXPCService.shared
        self.suggestionViewModel = SuggestionViewModel(xpcService: xpcService)
        self.quickActionsViewModel = QuickActionsViewModel(xpcService: xpcService)
        super.init()
        setupNotificationObservers()
    }
    
    // MARK: - MEComposeSessionHandler
    
    /// Called when a compose session begins
    func composeSessionDidBegin(_ session: MEComposeSession) {
        let sessionId = session.identifier
        print("[ComposeSessionHandler] Session began: \(sessionId)")
        
        // Create context for this session
        let context = ComposeSessionContext(
            session: session,
            injector: ComposeInjector(viewModel: suggestionViewModel),
            toolbarInjector: ToolbarInjector(viewModel: quickActionsViewModel)
        )
        activeSessions[sessionId] = context
        
        // Set up view models
        suggestionViewModel.composeSession = session
        quickActionsViewModel.composeSession = session
        
        // Inject UI components
        DispatchQueue.main.async { [weak self] in
            self?.injectUI(for: context)
        }
        
        // Analyze initial context
        analyzeComposeContext(session)
    }
    
    /// Called when a compose session ends
    func composeSessionDidEnd(_ session: MEComposeSession) {
        let sessionId = session.identifier
        print("[ComposeSessionHandler] Session ended: \(sessionId)")
        
        // Clean up
        if let context = activeSessions[sessionId] {
            context.cleanup()
            activeSessions.removeValue(forKey: sessionId)
        }
    }
    
    /// Called when the message being composed changes
    func session(_ session: MEComposeSession, didChange message: MEMessage) {
        Task {
            await handleMessageChange(session, message: message)
        }
    }
    
    /// Provides address suggestions
    func session(_ session: MEComposeSession, provideSuggestionsFor address: MEAddress) -> [MEAddressSuggestion]? {
        // Could provide smart suggestions based on context
        return nil
    }
    
    /// Called to check if the message can be sent
    func session(_ session: MEComposeSession, canSendMessage message: MEMessage) -> Bool {
        // Could implement pre-send checks
        return true
    }
    
    /// Called when the user attempts to send the message
    func session(_ session: MEComposeSession, sendMessage message: MEMessage) async -> MEComposeSession.SendResult {
        // Could perform final checks or modifications
        return .success
    }
    
    // MARK: - UI Injection
    
    private func injectUI(for context: ComposeSessionContext) {
        // Find the compose window
        guard let window = findComposeWindow(for: context.session) else {
            print("[ComposeSessionHandler] Could not find compose window")
            return
        }
        
        // Inject suggestion panel
        context.injector.inject(into: window, for: context.session)
        
        // Inject toolbar items
        context.toolbarInjector.inject(into: window, for: context.session)
        
        print("[ComposeSessionHandler] UI injected for session: \(context.session.identifier)")
    }
    
    private func findComposeWindow(for session: MEComposeSession) -> NSWindow? {
        // Try to find the window for this session
        for window in NSApp.windows {
            // Check if this window is associated with our session
            // This is heuristic-based
            if isComposeWindow(window, for: session) {
                return window
            }
        }
        return NSApp.keyWindow
    }
    
    private func isComposeWindow(_ window: NSWindow, for session: MEComposeSession) -> Bool {
        // Check window properties to determine if it's our compose window
        let title = window.title.lowercased()
        return title.contains("compose") || 
               title.contains("reply") || 
               title.contains("forward") ||
               title.contains("new message")
    }
    
    // MARK: - Message Handling
    
    private func handleMessageChange(_ session: MEComposeSession, message: MEMessage) async {
        guard let body = message.plainTextBody else { return }
        
        // Debounce rapid changes
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Check if still the current session
        guard activeSessions[session.identifier] != nil else { return }
        
        // Don't suggest if message is too short
        guard body.count > 20 else { return }
        
        // Check for writing assistance triggers
        await checkWritingTriggers(session, message: message, body: body)
    }
    
    private func checkWritingTriggers(_ session: MEComposeSession, message: MEMessage, body: String) async {
        // Check for specific triggers that might warrant suggestions
        let triggers = [
            "help me write",
            "draft a",
            "respond to",
            "reply to"
        ]
        
        let lowerBody = body.lowercased()
        for trigger in triggers {
            if lowerBody.contains(trigger) {
                // Show suggestion to generate response
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .showSuggestionPanel,
                        object: nil
                    )
                }
                break
            }
        }
    }
    
    // MARK: - Context Analysis
    
    private func analyzeComposeContext(_ session: MEComposeSession) {
        let message = session.message
        
        // Determine if this is a reply, forward, or new message
        let isReply = session.mailboxURL?.absoluteString.contains("reply") ?? false
        let isForward = session.mailboxURL?.absoluteString.contains("forward") ?? false
        
        print("[ComposeSessionHandler] Context - Reply: \(isReply), Forward: \(isForward)")
        
        // Could pre-load suggestions based on context
        if isReply || isForward {
            // Pre-analyze the original message
        }
    }
    
    // MARK: - Notification Handlers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardShortcut(_:)),
            name: .keyboardShortcutGenerate,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowPanel(_:)),
            name: .showSuggestionPanel,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInsertSuggestion(_:)),
            name: .insertSuggestion,
            object: nil
        )
    }
    
    @objc private func handleKeyboardShortcut(_ notification: Notification) {
        guard let session = activeSessions.values.first?.session else { return }
        suggestionViewModel.generateSuggestions()
    }
    
    @objc private func handleShowPanel(_ notification: Notification) {
        guard let context = activeSessions.values.first else { return }
        context.injector.showPanel(for: context.session)
    }
    
    @objc private func handleInsertSuggestion(_ notification: Notification) {
        guard let response = notification.userInfo?["response"] as? GeneratedResponse,
              let context = activeSessions.values.first else { return }
        
        insertResponse(response, into: context.session)
    }
    
    private func insertResponse(_ response: GeneratedResponse, into session: MEComposeSession) {
        // Post notification for the compose injector to handle
        NotificationCenter.default.post(
            name: .didInsertSuggestion,
            object: nil,
            userInfo: [
                "text": response.text,
                "sessionId": session.identifier
            ]
        )
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        for (_, context) in activeSessions {
            context.cleanup()
        }
        activeSessions.removeAll()
    }
}

// MARK: - Compose Session Context

/// Holds context for an active compose session
class ComposeSessionContext {
    let session: MEComposeSession
    let injector: ComposeInjector
    let toolbarInjector: ToolbarInjector
    
    init(session: MEComposeSession, 
         injector: ComposeInjector,
         toolbarInjector: ToolbarInjector) {
        self.session = session
        self.injector = injector
        self.toolbarInjector = toolbarInjector
    }
    
    func cleanup() {
        injector.remove(from: session)
        if let window = ComposeWindowFinder.findWindow(for: session) {
            toolbarInjector.remove(from: window)
        }
    }
}

// MARK: - Supporting Types

/// Legacy support types (kept for compatibility)
struct WritingSuggestion {
    let text: String
    let replacementRange: NSRange
    let confidence: Double
    let category: SuggestionCategory
}

enum SuggestionCategory {
    case completion
    case rewrite
    case tone
    case action
}

struct SuggestionContext {
    let subject: String
    let recipients: [String]
    let isReply: Bool
}

/// Legacy provider (redirects to new implementation)
class SuggestionProvider {
    func suggestCompletions(for text: String, context: SuggestionContext) async -> [WritingSuggestion] {
        // Redirect to new implementation
        return []
    }
}
