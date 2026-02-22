//
//  MessageViewController.swift
//  MailExtension
//

import MailKit

class MessageViewController: MEExtensionViewController {
    
    // MARK: - Properties
    
    private var currentMessage: MEMessage?
    private var suggestionView: SuggestionOverlayView?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Setup the extension's UI
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    // MARK: - MEMessageViewController Overrides
    
    override func decorate(_ message: MEMessage) {
        currentMessage = message
        
        // Analyze the message and provide decorations
        Task {
            await analyzeMessage(message)
        }
    }
    
    override func decorate(_ address: MEAddress, for message: MEMessage) -> MEAddressDecoration? {
        // Add decorations to email addresses (e.g., known contacts, VIP status)
        return nil
    }
    
    override func decorate(_ attachment: MEAttachment, for message: MEMessage) -> MEAttachmentDecoration? {
        // Add decorations to attachments
        return nil
    }
    
    // MARK: - Message Analysis
    
    private func analyzeMessage(_ message: MEMessage) async {
        // Connect to XPC service for AI analysis
        let emailContent = EmailContent(
            subject: message.subject,
            body: message.plainTextBody ?? "",
            sender: message.sender?.formatted ?? "",
            recipients: message.toAddresses.map { $0.formatted },
            threadMessages: nil
        )
        
        // Request suggestions from service
        await requestSuggestions(for: emailContent)
    }
    
    private func requestSuggestions(for email: EmailContent) async {
        // Implementation would connect to XPC service
        // This is a placeholder for the actual implementation
    }
    
    // MARK: - Suggestion Display
    
    private func showSuggestions(_ suggestions: [GeneratedResponse]) {
        // Display AI-generated suggestions in the Mail compose window
        // Already on MainActor, no need for DispatchQueue.main.async
        // Update UI with suggestions
    }
}



// MARK: - Supporting Types

class SuggestionOverlayView: NSView {
    // Custom view for displaying suggestions overlay
}

extension MEAddress {
    var formatted: String {
        if let displayName = displayName {
            return "\(displayName) <\(address)>"
        }
        return address
    }
}
