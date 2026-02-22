//
//  AppStateManager.swift
//  MailAssistant
//
//  Global app state management with @AppStorage persistence.
//

import SwiftUI
import Combine

/// Manages global application state, onboarding flow, and XPC service communication
@MainActor
class AppStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Connection status to the XPC service
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    /// Whether an analysis operation is currently running
    @Published var isAnalyzing = false
    
    /// List of available plugins
    @Published var availablePlugins: [Plugin] = []
    
    /// Currently filtered/sorted emails for display
    @Published var filteredEmails: [EmailSummary] = []
    
    /// Activity history for the history view
    @Published var activityHistory: [ActivityItem] = []
    
    /// Favorite plugins for quick access in sidebar
    @Published var favoritePlugins: [Plugin] = []
    
    /// Unread email count for dashboard
    @Published var unreadCount: Int = 0
    
    // MARK: - AppStorage Properties
    
    /// Whether the user has completed onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    /// Selected AI provider
    @AppStorage("selectedProvider") var selectedProvider = AIProvider.kimi.rawValue
    
    /// Whether auto-analysis is enabled
    @AppStorage("enableAutoAnalysis") var enableAutoAnalysis = true
    
    /// Local-only mode (no cloud AI)
    @AppStorage("localOnlyMode") var localOnlyMode = false
    
    /// Selected mail accounts
    @AppStorage("selectedMailAccounts") var selectedMailAccountsData = Data()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let xpcManager = XPCServiceManager.shared
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe XPC connection status
        xpcManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.connectionStatus = isConnected ? .connected : .disconnected
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        // Load sample plugins for demo
        loadSamplePlugins()
        
        // Load sample emails for demo
        loadSampleEmails()
        
        // Load sample activity history
        loadSampleActivity()
    }
    
    // MARK: - Onboarding
    
    /// Completes the onboarding flow and saves the state
    func completeOnboarding() {
        hasCompletedOnboarding = true
        
        // Initialize services after onboarding
        Task {
            await initializeServices()
        }
    }
    
    /// Resets onboarding state (for testing)
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
    
    // MARK: - Services
    
    private func initializeServices() async {
        connectionStatus = .connecting
        
        // Connect to XPC service
        xpcManager.connect()
        
        // Wait for connection
        try? await Task.sleep(for: .seconds(0.5))
        
        if xpcManager.isConnected {
            connectionStatus = .connected
        } else {
            connectionStatus = .error("Failed to connect to service")
        }
    }
    
    // MARK: - Plugin Management
    
    /// Returns whether a plugin is currently enabled
    func isPluginEnabled(_ plugin: Plugin) -> Bool {
        // In a real implementation, this would check UserDefaults or database
        return UserDefaults.standard.bool(forKey: "plugin_enabled_\(plugin.id)")
    }
    
    /// Toggles the enabled state of a plugin
    func togglePlugin(_ plugin: Plugin) {
        let currentState = isPluginEnabled(plugin)
        UserDefaults.standard.set(!currentState, forKey: "plugin_enabled_\(plugin.id)")
        objectWillChange.send()
    }
    
    /// Activates a plugin (for quick access actions)
    func activatePlugin(_ plugin: Plugin) {
        // Implementation would trigger plugin-specific action
        addActivity(
            title: "Activated \(plugin.name)",
            icon: plugin.icon,
            color: .purple,
            result: nil
        )
    }
    
    /// Returns list of enabled plugins
    var enabledPlugins: [Plugin] {
        availablePlugins.filter { isPluginEnabled($0) }
    }
    
    // MARK: - Email Operations
    
    /// Refreshes emails from Mail.app
    func refreshEmails() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Simulate XPC call to service
        try? await Task.sleep(for: .seconds(1))
        
        // Refresh sample data
        loadSampleEmails()
        
        addActivity(
            title: "Refreshed emails",
            icon: "arrow.clockwise",
            color: .blue,
            result: "\(filteredEmails.count) emails"
        )
    }
    
    /// Analyzes a specific email
    func analyzeEmail(_ email: EmailSummary) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Simulate XPC call
        try? await Task.sleep(for: .seconds(0.5))
        
        addActivity(
            title: "Analyzed email",
            icon: "brain",
            color: .green,
            result: "Completed"
        )
    }
    
    /// Generates a reply for an email
    func generateReply(for email: EmailSummary) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Simulate XPC call
        try? await Task.sleep(for: .seconds(1))
        
        addActivity(
            title: "Generated reply",
            icon: "envelope",
            color: .blue,
            result: "Ready"
        )
    }
    
    /// Marks an email as read
    func markAsRead(_ email: EmailSummary) async {
        // Simulate XPC call
        try? await Task.sleep(for: .milliseconds(100))
        
        addActivity(
            title: "Marked as read",
            icon: "envelope.open",
            color: .gray,
            result: nil
        )
    }
    
    // MARK: - Activity History
    
    private func addActivity(title: String, icon: String, color: Color, result: String?) {
        let activity = ActivityItem(
            id: UUID(),
            title: title,
            icon: icon,
            color: color,
            timestamp: Date(),
            result: result
        )
        activityHistory.insert(activity, at: 0)
        
        // Limit history size
        if activityHistory.count > 100 {
            activityHistory = Array(activityHistory.prefix(100))
        }
    }
    
    // MARK: - Sample Data (for demo/development)
    
    private func loadSamplePlugins() {
        availablePlugins = [
            Plugin(
                id: UUID(),
                name: "Smart Reply",
                description: "AI-powered reply suggestions based on email context and your writing style.",
                icon: "envelope.badge.fill",
                version: "1.0.0",
                isInstalled: true
            ),
            Plugin(
                id: UUID(),
                name: "Email Summarizer",
                description: "Automatically summarizes long email threads for quick reading.",
                icon: "text.alignleft",
                version: "1.0.0",
                isInstalled: true
            ),
            Plugin(
                id: UUID(),
                name: "Priority Inbox",
                description: "Intelligently prioritizes incoming emails based on importance.",
                icon: "flag.fill",
                version: "1.0.0",
                isInstalled: true
            ),
            Plugin(
                id: UUID(),
                name: "Grammar Check",
                description: "Advanced grammar and style checking for your outgoing emails.",
                icon: "checkmark.bubble",
                version: "1.0.0",
                isInstalled: true
            )
        ]
        
        // Set some as favorites for quick access
        favoritePlugins = Array(availablePlugins.prefix(2))
    }
    
    private func loadSampleEmails() {
        filteredEmails = [
            EmailSummary(
                id: UUID(),
                sender: "Alice Johnson",
                subject: "Project Update - Q1 Review",
                preview: "Hi team, I wanted to share the latest updates on our Q1 project progress. We've completed...",
                receivedDate: Date().addingTimeInterval(-3600),
                isAnalyzed: true,
                tags: ["Work", "Project"]
            ),
            EmailSummary(
                id: UUID(),
                sender: "Bob Smith",
                subject: "Meeting Notes: Design Review",
                preview: "Thanks everyone for attending today's design review. Here are the key takeaways...",
                receivedDate: Date().addingTimeInterval(-7200),
                isAnalyzed: true,
                tags: ["Meeting"]
            ),
            EmailSummary(
                id: UUID(),
                sender: "support@example.com",
                subject: "Your ticket #12345 has been resolved",
                preview: "Dear customer, we're writing to inform you that your support ticket has been resolved...",
                receivedDate: Date().addingTimeInterval(-10800),
                isAnalyzed: false,
                tags: ["Support"]
            ),
            EmailSummary(
                id: UUID(),
                sender: "newsletter@tech.com",
                subject: "Weekly Tech Digest",
                preview: "This week in tech: new AI breakthroughs, Apple announcements, and more...",
                receivedDate: Date().addingTimeInterval(-86400),
                isAnalyzed: false,
                tags: ["Newsletter"]
            ),
            EmailSummary(
                id: UUID(),
                sender: "Sarah Chen",
                subject: "Lunch next week?",
                preview: "Hey! Are you free for lunch next Tuesday? There's a great new place downtown...",
                receivedDate: Date().addingTimeInterval(-172800),
                isAnalyzed: true,
                tags: ["Personal"]
            )
        ]
    }
    
    private func loadSampleActivity() {
        activityHistory = [
            ActivityItem(
                id: UUID(),
                title: "Analyzed 5 emails",
                icon: "brain",
                color: .green,
                timestamp: Date().addingTimeInterval(-300),
                result: "3 high priority"
            ),
            ActivityItem(
                id: UUID(),
                title: "Generated reply draft",
                icon: "envelope",
                color: .blue,
                timestamp: Date().addingTimeInterval(-900),
                result: "Ready to send"
            ),
            ActivityItem(
                id: UUID(),
                title: "Plugin updated",
                icon: "puzzlepiece",
                color: .purple,
                timestamp: Date().addingTimeInterval(-3600),
                result: "Smart Reply v1.0.1"
            ),
            ActivityItem(
                id: UUID(),
                title: "Connected to Mail.app",
                icon: "checkmark.shield",
                color: .green,
                timestamp: Date().addingTimeInterval(-7200),
                result: nil
            )
        ]
    }
}

// MARK: - Supporting Types

enum ConnectionStatus: CustomStringConvertible {
    case connected
    case connecting
    case disconnected
    case error(String)
    
    var description: String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        }
    }
}

struct EmailSummary: Identifiable {
    let id: UUID
    let sender: String
    let subject: String
    let preview: String
    let receivedDate: Date
    let isAnalyzed: Bool
    let tags: [String]
}

struct Plugin: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let version: String
    let isInstalled: Bool
}

struct ActivityItem: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let color: Color
    let timestamp: Date
    let result: String?
}

// MARK: - Notification Names

extension Notification.Name {
    static let newDraftRequested = Notification.Name("newDraftRequested")
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
    static let analyzeEmail = Notification.Name("analyzeEmail")
}
