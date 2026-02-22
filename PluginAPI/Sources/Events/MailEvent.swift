import Foundation

// MARK: - Mail Event

/// All possible events that can occur in the mail system
public enum MailEvent: Sendable {
    // MARK: - Email Events
    
    /// An email was received
    case emailReceived(email: Email)
    
    /// An email was sent
    case emailSent(email: Email)
    
    /// An email was opened/read
    case emailOpened(emailID: UUID, userID: String)
    
    /// An email was marked as read
    case emailMarkedAsRead(emailID: UUID)
    
    /// An email was marked as unread
    case emailMarkedAsUnread(emailID: UUID)
    
    /// An email was archived
    case emailArchived(emailID: UUID)
    
    /// An email was deleted
    case emailDeleted(emailID: UUID, permanently: Bool)
    
    /// An email was restored from trash
    case emailRestored(emailID: UUID)
    
    /// An email was moved to a folder
    case emailMoved(emailID: UUID, fromFolder: String, toFolder: String)
    
    /// An email was flagged/starred
    case emailFlagged(emailID: UUID)
    
    /// An email was unflagged
    case emailUnflagged(emailID: UUID)
    
    /// An email's labels changed
    case emailLabelsChanged(emailID: UUID, added: [String], removed: [String])
    
    /// An email was snoozed
    case emailSnoozed(emailID: UUID, until: Date)
    
    /// An email's importance was changed
    case emailImportanceChanged(emailID: UUID, importance: EmailImportance)
    
    // MARK: - Thread Events
    
    /// A new thread was created
    case threadCreated(threadID: UUID, subject: String)
    
    /// A reply was added to a thread
    case threadReplied(threadID: UUID, emailID: UUID)
    
    /// A thread was archived
    case threadArchived(threadID: UUID)
    
    /// A thread was deleted
    case threadDeleted(threadID: UUID)
    
    // MARK: - Compose Events
    
    /// User started composing a new email
    case composeStarted(draftID: UUID, isReply: Bool, originalEmailID: UUID?)
    
    /// Draft was saved
    case draftSaved(draftID: UUID)
    
    /// Draft was discarded
    case draftDiscarded(draftID: UUID)
    
    /// Email was scheduled to send
    case emailScheduled(emailID: UUID, scheduledFor: Date)
    
    /// Send was cancelled
    case sendCancelled(draftID: UUID)
    
    // MARK: - Analysis Events
    
    /// Analysis was requested for an email
    case analysisRequested(emailID: UUID, types: [AnalysisType])
    
    /// Analysis completed for an email
    case analysisCompleted(emailID: UUID, result: AnalysisResult)
    
    /// Insights were generated
    case insightsGenerated(emailID: UUID, insights: [Insight])
    
    /// Response suggestions were generated
    case responseSuggestionsGenerated(emailID: UUID, suggestions: [ResponseSuggestion])
    
    /// Writing style was analyzed
    case writingStyleAnalyzed(emailID: UUID, profile: WritingProfile)
    
    // MARK: - AI Events
    
    /// AI generation was requested
    case aiGenerationRequested(requestID: UUID, type: AIGenerationType)
    
    /// AI generation completed
    case aiGenerationCompleted(requestID: UUID, response: GenerationResponse)
    
    /// AI generation failed
    case aiGenerationFailed(requestID: UUID, error: String)
    
    // MARK: - Action Events
    
    /// An action was triggered
    case actionTriggered(action: ActionType, context: ActionContext)
    
    /// An action completed
    case actionCompleted(result: ActionResult)
    
    /// A rule was executed
    case ruleExecuted(ruleID: String, emailID: UUID, actions: [ActionType])
    
    // MARK: - Integration Events
    
    /// Integration connected
    case integrationConnected(pluginID: String, integrationType: IntegrationType)
    
    /// Integration disconnected
    case integrationDisconnected(pluginID: String, reason: String?)
    
    /// Sync started
    case syncStarted(pluginID: String, dataType: SyncDataType)
    
    /// Sync completed
    case syncCompleted(pluginID: String, result: SyncResult)
    
    /// Sync failed
    case syncFailed(pluginID: String, error: String)
    
    /// External event received
    case externalEventReceived(pluginID: String, event: ExternalEvent)
    
    // MARK: - Plugin Events
    
    /// Plugin was installed
    case pluginInstalled(pluginID: String, metadata: PluginMetadata)
    
    /// Plugin was activated
    case pluginActivated(pluginID: String)
    
    /// Plugin was deactivated
    case pluginDeactivated(pluginID: String)
    
    /// Plugin was updated
    case pluginUpdated(pluginID: String, fromVersion: String, toVersion: String)
    
    /// Plugin was uninstalled
    case pluginUninstalled(pluginID: String)
    
    /// Plugin error occurred
    case pluginError(pluginID: String, error: String)
    
    // MARK: - UI Events
    
    /// View changed
    case viewChanged(from: String, to: String)
    
    /// Search was performed
    case searchPerformed(query: String, resultCount: Int)
    
    /// Filter was applied
    case filterApplied(filter: EmailFilter)
    
    /// Settings were changed
    case settingsChanged(section: String, key: String, oldValue: AnyCodable?, newValue: AnyCodable?)
    
    // MARK: - System Events
    
    /// App launched
    case appLaunched
    
    /// App will terminate
    case appWillTerminate
    
    /// Account connected
    case accountConnected(accountID: String, provider: String)
    
    /// Account disconnected
    case accountDisconnected(accountID: String)
    
    /// Network status changed
    case networkStatusChanged(isOnline: Bool)
    
    /// Error occurred
    case errorOccurred(error: String, context: [String: AnyCodable])
    
    /// Custom event for plugin-specific use
    case custom(name: String, data: [String: AnyCodable])
}

// MARK: - AI Generation Type

public enum AIGenerationType: String, Codable, Sendable {
    case reply
    case summary
    case rewrite
    case translate
    case analyze
    case suggestActions = "suggest_actions"
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = AIGenerationType(rawValue: rawValue) {
            self = standard
        } else {
            self = .custom(rawValue)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .custom(let value):
            try container.encode(value)
        default:
            try container.encode(self.rawValue)
        }
    }
}

// MARK: - Email Filter

public struct EmailFilter: Codable, Sendable {
    public let searchQuery: String?
    public let from: [String]?
    public let to: [String]?
    public let subject: String?
    public let hasAttachments: Bool?
    public let dateRange: DateRange?
    public let labels: [String]?
    public let importance: EmailImportance?
    public let isRead: Bool?
    public let isFlagged: Bool?
    
    public init(
        searchQuery: String? = nil,
        from: [String]? = nil,
        to: [String]? = nil,
        subject: String? = nil,
        hasAttachments: Bool? = nil,
        dateRange: DateRange? = nil,
        labels: [String]? = nil,
        importance: EmailImportance? = nil,
        isRead: Bool? = nil,
        isFlagged: Bool? = nil
    ) {
        self.searchQuery = searchQuery
        self.from = from
        self.to = to
        self.subject = subject
        self.hasAttachments = hasAttachments
        self.dateRange = dateRange
        self.labels = labels
        self.importance = importance
        self.isRead = isRead
        self.isFlagged = isFlagged
    }
}

// MARK: - Date Range

public struct DateRange: Codable, Sendable {
    public let start: Date
    public let end: Date
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

// MARK: - Event Subscriber

/// Protocol for components that subscribe to events
public protocol EventSubscriber: Sendable {
    /// Unique identifier for this subscriber
    var subscriberID: String { get }
    
    /// The events this subscriber is interested in
    var subscribedEvents: [MailEventType] { get }
    
    /// Called when a subscribed event occurs
    func handleEvent(_ event: MailEvent) async
}

// MARK: - Mail Event Type

/// Categories of mail events for filtering subscriptions
public enum MailEventType: String, Sendable, CaseIterable {
    case emailReceived = "email.received"
    case emailSent = "email.sent"
    case emailOpened = "email.opened"
    case emailStatusChanged = "email.status_changed"
    case emailMoved = "email.moved"
    case emailDeleted = "email.deleted"
    
    case threadCreated = "thread.created"
    case threadUpdated = "thread.updated"
    
    case composeStarted = "compose.started"
    case draftSaved = "draft.saved"
    case draftDiscarded = "draft.discarded"
    
    case analysisRequested = "analysis.requested"
    case analysisCompleted = "analysis.completed"
    
    case aiGenerationRequested = "ai.generation_requested"
    case aiGenerationCompleted = "ai.generation_completed"
    case aiGenerationFailed = "ai.generation_failed"
    
    case actionTriggered = "action.triggered"
    case actionCompleted = "action.completed"
    
    case integrationConnected = "integration.connected"
    case integrationDisconnected = "integration.disconnected"
    case syncStarted = "sync.started"
    case syncCompleted = "sync.completed"
    case syncFailed = "sync.failed"
    
    case pluginInstalled = "plugin.installed"
    case pluginActivated = "plugin.activated"
    case pluginDeactivated = "plugin.deactivated"
    case pluginUpdated = "plugin.updated"
    case pluginUninstalled = "plugin.uninstalled"
    case pluginError = "plugin.error"
    
    case viewChanged = "ui.view_changed"
    case searchPerformed = "ui.search_performed"
    case settingsChanged = "ui.settings_changed"
    
    case appLifecycle = "system.app_lifecycle"
    case accountStatus = "system.account_status"
    case networkStatus = "system.network_status"
    case errorOccurred = "system.error"
    
    case all = "*"
    case custom(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let standard = MailEventType(rawValue: rawValue) {
            self = standard
        } else {
            self = .custom(rawValue)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .custom(let value):
            try container.encode(value)
        default:
            try container.encode(self.rawValue)
        }
    }
    
    public static var allCases: [MailEventType] {
        [
            .emailReceived, .emailSent, .emailOpened, .emailStatusChanged,
            .emailMoved, .emailDeleted, .threadCreated, .threadUpdated,
            .composeStarted, .draftSaved, .draftDiscarded,
            .analysisRequested, .analysisCompleted,
            .aiGenerationRequested, .aiGenerationCompleted, .aiGenerationFailed,
            .actionTriggered, .actionCompleted,
            .integrationConnected, .integrationDisconnected,
            .syncStarted, .syncCompleted, .syncFailed,
            .pluginInstalled, .pluginActivated, .pluginDeactivated,
            .pluginUpdated, .pluginUninstalled, .pluginError,
            .viewChanged, .searchPerformed, .settingsChanged,
            .appLifecycle, .accountStatus, .networkStatus, .errorOccurred,
            .all
        ]
    }
}

// MARK: - Event Bus

/// Central event bus for publish/subscribe pattern
public protocol EventBus: Sendable {
    /// Publish an event to all subscribers
    func publish(_ event: MailEvent) async
    
    /// Subscribe to events matching the given types
    func subscribe(_ subscriber: EventSubscriber) async
    
    /// Unsubscribe from events
    func unsubscribe(_ subscriberID: String) async
    
    /// Subscribe with a closure (for one-off subscriptions)
    func subscribe(
        subscriberID: String,
        to eventTypes: [MailEventType],
        handler: @escaping @Sendable (MailEvent) async -> Void
    ) async -> Subscription
    
    /// Get all active subscriptions
    func activeSubscriptions() async -> [SubscriptionInfo]
}

// MARK: - Subscription

/// Represents an active event subscription
public struct Subscription: Sendable {
    public let id: String
    public let subscriberID: String
    public let eventTypes: [MailEventType]
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        subscriberID: String,
        eventTypes: [MailEventType],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.subscriberID = subscriberID
        self.eventTypes = eventTypes
        self.createdAt = createdAt
    }
}

// MARK: - Subscription Info

public struct SubscriptionInfo: Codable, Sendable {
    public let id: String
    public let subscriberID: String
    public let eventTypes: [String]
    public let createdAt: Date
    
    public init(
        id: String,
        subscriberID: String,
        eventTypes: [String],
        createdAt: Date
    ) {
        self.id = id
        self.subscriberID = subscriberID
        self.eventTypes = eventTypes
        self.createdAt = createdAt
    }
}

// MARK: - Event Bus Placeholder Implementation

/// Placeholder implementation of EventBus for compilation
public actor PlaceholderEventBus: EventBus {
    private var subscribers: [String: EventSubscriber] = [:]
    private var handlers: [String: [(MailEvent) async -> Void]] = [:]
    private var subscriptions: [Subscription] = []
    
    public init() {}
    
    public func publish(_ event: MailEvent) async {
        // In real implementation: route to all matching subscribers
        for (id, handler) in handlers {
            await handler(event)
        }
    }
    
    public func subscribe(_ subscriber: EventSubscriber) async {
        subscribers[subscriber.subscriberID] = subscriber
    }
    
    public func unsubscribe(_ subscriberID: String) async {
        subscribers.removeValue(forKey: subscriberID)
        handlers.removeValue(forKey: subscriberID)
        subscriptions.removeAll { $0.subscriberID == subscriberID }
    }
    
    public func subscribe(
        subscriberID: String,
        to eventTypes: [MailEventType],
        handler: @escaping @Sendable (MailEvent) async -> Void
    ) async -> Subscription {
        handlers[subscriberID] = [handler]
        let subscription = Subscription(
            subscriberID: subscriberID,
            eventTypes: eventTypes
        )
        subscriptions.append(subscription)
        return subscription
    }
    
    public func activeSubscriptions() async -> [SubscriptionInfo] {
        subscriptions.map {
            SubscriptionInfo(
                id: $0.id,
                subscriberID: $0.subscriberID,
                eventTypes: $0.eventTypes.map { $0.rawValue },
                createdAt: $0.createdAt
            )
        }
    }
}
