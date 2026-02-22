//
//  ComposeInjector.swift
//  MailExtension
//

import Cocoa
import SwiftUI
import MailKit

/// Injects the suggestion panel into the compose window
class ComposeInjector: NSObject {
    
    // MARK: - Properties
    
    private var activePanels: [String: SuggestionPanelController] = [:]
    private var windowObservers: [String: NSKeyValueObservation] = [:]
    private var composeSession: MEComposeSession?
    private let viewModel: SuggestionViewModel
    
    // MARK: - Initialization
    
    init(viewModel: SuggestionViewModel) {
        self.viewModel = viewModel
        super.init()
        setupNotificationObservers()
    }
    
    deinit {
        windowObservers.values.forEach { $0.invalidate() }
        windowObservers.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Injects the suggestion panel into a compose window
    func inject(into window: NSWindow, for session: MEComposeSession) {
        let sessionId = session.identifier
        self.composeSession = session
        
        // Check if already injected
        guard activePanels[sessionId] == nil else { return }
        
        // Find or create the injection point
        guard let containerView = findComposeContainer(in: window) else {
            print("[ComposeInjector] Could not find compose container view")
            return
        }
        
        // Create the suggestion panel
        let panelController = createSuggestionPanel(for: session)
        
        // Add to container
        injectPanel(panelController.view, into: containerView)
        
        // Store reference
        activePanels[sessionId] = panelController
        
        // Setup window resize observer
        observeWindowResize(window, for: sessionId)
        
        print("[ComposeInjector] Successfully injected panel for session: \(sessionId)")
    }
    
    /// Removes the suggestion panel from a compose window
    func remove(from session: MEComposeSession) {
        let sessionId = session.identifier
        
        if let panel = activePanels[sessionId] {
            panel.close()
            activePanels.removeValue(forKey: sessionId)
        }
        
        windowObservers[sessionId]?.invalidate()
        windowObservers.removeValue(forKey: sessionId)
    }
    
    /// Updates the panel position when the window changes
    func updatePosition(for session: MEComposeSession) {
        guard let panel = activePanels[session.identifier] else { return }
        panel.updatePosition()
    }
    
    /// Shows the suggestion panel
    func showPanel(for session: MEComposeSession) {
        guard let panel = activePanels[session.identifier] else {
            // Try to find window and inject
            if let window = NSApp.keyWindow {
                inject(into: window, for: session)
            }
            return
        }
        panel.show()
    }
    
    /// Hides the suggestion panel
    func hidePanel(for session: MEComposeSession) {
        guard let panel = activePanels[session.identifier] else { return }
        panel.hide()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInsertSuggestion(_:)),
            name: .insertSuggestion,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowPanel(_:)),
            name: .showSuggestionPanel,
            object: nil
        )
    }
    
    /// Finds the compose container view in the window hierarchy
    private func findComposeContainer(in window: NSWindow) -> NSView? {
        guard let contentView = window.contentView else { return nil }
        
        // Try to find the compose text view's container
        // Mail.app uses various view hierarchies, we need to be flexible
        
        // Strategy 1: Look for known compose view classes
        if let composeView = findView(ofType: "MEComposeTextView", in: contentView) {
            return composeView.superview?.superview ?? composeView.superview
        }
        
        // Strategy 2: Look for the main scroll view
        if let scrollView = findView(ofType: "NSScrollView", in: contentView) {
            // The compose area is typically in a scroll view
            return scrollView.superview
        }
        
        // Strategy 3: Use the content view's first subview
        return contentView.subviews.first
    }
    
    /// Recursively searches for a view of a specific type
    private func findView(ofType typeName: String, in view: NSView) -> NSView? {
        let className = String(describing: type(of: view))
        if className.contains(typeName) {
            return view
        }
        
        for subview in view.subviews {
            if let found = findView(ofType: typeName, in: subview) {
                return found
            }
        }
        
        return nil
    }
    
    /// Creates the suggestion panel controller
    private func createSuggestionPanel(for session: MEComposeSession) -> SuggestionPanelController {
        viewModel.composeSession = session
        let panelView = SuggestionPanel(viewModel: viewModel)
        return SuggestionPanelController(contentView: panelView)
    }
    
    /// Injects the panel into the container view
    private func injectPanel(_ panelView: NSView, into containerView: NSView) {
        panelView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(panelView)
        
        // Position below the compose area
        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            panelView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            panelView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            panelView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }
    
    /// Observes window resize events
    private func observeWindowResize(_ window: NSWindow, for sessionId: String) {
        let observer = window.observe(\.frame, options: [.new]) { [weak self] window, _ in
            self?.handleWindowResize(sessionId: sessionId)
        }
        windowObservers[sessionId] = observer
    }
    
    private func handleWindowResize(sessionId: String) {
        guard let panel = activePanels[sessionId] else { return }
        panel.updatePosition()
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleInsertSuggestion(_ notification: Notification) {
        guard let response = notification.userInfo?["response"] as? GeneratedResponse,
              let session = composeSession else { return }
        
        insertText(response.text, into: session)
    }
    
    @objc private func handleShowPanel(_ notification: Notification) {
        guard let session = composeSession else { return }
        showPanel(for: session)
    }
    
    /// Inserts text into the compose session
    private func insertText(_ text: String, into session: MEComposeSession) {
        // Get the current message
        let message = session.message
        
        // Append or replace the message body
        let currentBody = message.plainTextBody ?? ""
        let newBody = currentBody.isEmpty ? text : "\(currentBody)\n\n\(text)"
        
        // Update the message
        // Note: MailKit API limitations may require alternative approaches
        // This is a placeholder for the actual implementation
        
        NotificationCenter.default.post(
            name: .didInsertSuggestion,
            object: nil,
            userInfo: ["text": text]
        )
    }
}

// MARK: - Suggestion Panel Controller

/// Manages the suggestion panel view
class SuggestionPanelController {
    private let hostingView: NSHostingView<SuggestionPanel>
    let view: NSView
    
    init(contentView: SuggestionPanel) {
        self.hostingView = NSHostingView(rootView: contentView)
        self.view = hostingView
        
        setupView()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        
        // Hide initially
        view.isHidden = true
    }
    
    func show() {
        view.isHidden = false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            view.animator().alphaValue = 1.0
        }
    }
    
    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            view.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            self?.view.isHidden = true
        }
    }
    
    func updatePosition() {
        // Update constraints or frame if needed
    }
    
    func close() {
        hide()
        view.removeFromSuperview()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let didInsertSuggestion = Notification.Name("com.rabitem.KimiMailAssistant.didInsertSuggestion")
}

// MARK: - Compose Window Finder

/// Helper to find compose windows
class ComposeWindowFinder {
    
    /// Finds the compose window for a given session
    static func findWindow(for session: MEComposeSession) -> NSWindow? {
        let sessionId = session.identifier
        
        for window in NSApp.windows {
            // Check if this window contains our session
            if windowIdentifierMatches(window, sessionId: sessionId) {
                return window
            }
        }
        
        return nil
    }
    
    private static func windowIdentifierMatches(_ window: NSWindow, sessionId: String) -> Bool {
        // Check window title or other identifiers
        // This is heuristic-based and may need adjustment
        return window.title.contains("Compose") || 
               window.title.contains("Reply") ||
               window.title.contains("Forward")
    }
}
