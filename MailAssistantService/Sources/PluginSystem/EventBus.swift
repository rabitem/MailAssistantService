import Foundation
import PluginAPI

/// Event bus implementation for pub/sub event system
public actor EventBusImpl: EventBus {
    /// Subscription entry
    private struct Subscription: Sendable {
        let id: EventSubscription
        let eventType: String?
        let handler: @Sendable (AnyPluginEvent) async -> Void
    }
    
    /// Active subscriptions
    private var subscriptions: [EventSubscription: Subscription] = [:]
    
    /// Event queue for reliable delivery
    private var eventQueue: [AnyPluginEvent] = []
    private let maxQueueSize: Int
    
    /// Event history for replay
    private var eventHistory: [String: AnyPluginEvent] = [:]
    private let maxHistoryCount: Int
    
    /// Task for processing queued events
    private var processingTask: Task<Void, Never>?
    
    /// Logger for event bus
    private let logger: ((String) -> Void)?
    
    /// Track event metrics
    private var metrics = EventMetrics()
    
    public init(
        maxQueueSize: Int = 1000,
        maxHistoryCount: Int = 100,
        logger: ((String) -> Void)? = nil
    ) {
        self.maxQueueSize = maxQueueSize
        self.maxHistoryCount = maxHistoryCount
        self.logger = logger
    }
    
    deinit {
        processingTask?.cancel()
    }
    
    // MARK: - EventBus Protocol
    
    public func subscribe<E: PluginEvent>(
        to eventType: E.Type,
        handler: @escaping @Sendable (E) async -> Void
    ) -> EventSubscription {
        let subscription = EventSubscription()
        let typeString = E.eventType
        
        subscriptions[subscription] = Subscription(
            id: subscription,
            eventType: typeString,
            handler: { anyEvent in
                // This is safe because we only call this handler for matching event types
                if let event = anyEvent.payload as? E {
                    await handler(event)
                }
            }
        )
        
        logger?("[EventBus] Subscribed \(subscription.id) to \(typeString)")
        return subscription
    }
    
    public func subscribeToAll(
        handler: @escaping @Sendable (AnyPluginEvent) async -> Void
    ) -> EventSubscription {
        let subscription = EventSubscription()
        
        subscriptions[subscription] = Subscription(
            id: subscription,
            eventType: nil, // nil means all events
            handler: handler
        )
        
        logger?("[EventBus] Subscribed \(subscription.id) to all events")
        return subscription
    }
    
    public func publish<E: PluginEvent>(_ event: E) async {
        let wrappedEvent = AnyPluginEvent(event, payload: event)
        
        // Add to queue for reliability
        await queueEvent(wrappedEvent)
        
        // Process immediately
        await processEvent(wrappedEvent)
        
        // Store in history
        await storeInHistory(wrappedEvent)
    }
    
    public func unsubscribe(_ subscription: EventSubscription) {
        subscriptions.removeValue(forKey: subscription)
        logger?("[EventBus] Unsubscribed \(subscription.id)")
    }
    
    // MARK: - Internal Methods
    
    private func queueEvent(_ event: AnyPluginEvent) {
        // Maintain queue size limit
        while eventQueue.count >= maxQueueSize {
            eventQueue.removeFirst()
            metrics.droppedEvents += 1
        }
        eventQueue.append(event)
        metrics.queuedEvents += 1
    }
    
    private func processEvent(_ event: AnyPluginEvent) async {
        metrics.publishedEvents += 1
        
        // Find matching subscriptions
        let matchingSubscriptions = subscriptions.values.filter { sub in
            sub.eventType == nil || sub.eventType == event.eventType
        }
        
        // Deliver to all subscribers concurrently
        await withTaskGroup(of: Void.self) { group in
            for subscription in matchingSubscriptions {
                group.addTask { [weak self] in
                    await self?.deliver(event, to: subscription)
                }
            }
        }
    }
    
    private func deliver(_ event: AnyPluginEvent, to subscription: Subscription) async {
        do {
            await subscription.handler(event)
            metrics.deliveredEvents += 1
        } catch {
            logger?("[EventBus] Delivery error for \(subscription.id): \(error)")
            metrics.deliveryErrors += 1
        }
    }
    
    private func storeInHistory(_ event: AnyPluginEvent) {
        let key = "\(event.eventType)-\(event.eventId)"
        eventHistory[key] = event
        
        // Trim history if needed
        while eventHistory.count > maxHistoryCount {
            if let firstKey = eventHistory.keys.first {
                eventHistory.removeValue(forKey: firstKey)
            }
        }
    }
    
    // MARK: - Public API
    
    /// Replay events of a specific type from history
    public func replayEvents<E: PluginEvent>(
        ofType eventType: E.Type,
        limit: Int = 10
    ) async {
        let typeString = E.eventType
        let matchingEvents = eventHistory.values
            .filter { $0.eventType == typeString }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
        
        for event in matchingEvents {
            await processEvent(event)
        }
    }
    
    /// Clear all subscriptions and history
    public func reset() {
        subscriptions.removeAll()
        eventQueue.removeAll()
        eventHistory.removeAll()
        metrics = EventMetrics()
        logger?("[EventBus] Reset")
    }
    
    /// Get current metrics
    public var currentMetrics: EventMetrics {
        metrics
    }
}

/// Event metrics
public struct EventMetrics: Sendable {
    public var publishedEvents: UInt64 = 0
    public var deliveredEvents: UInt64 = 0
    public var queuedEvents: UInt64 = 0
    public var droppedEvents: UInt64 = 0
    public var deliveryErrors: UInt64 = 0
    
    public init() {}
}

/// Typed event subscription helper
public final class TypedEventSubscription<E: PluginEvent>: Sendable {
    private let subscription: EventSubscription
    private let eventBus: EventBus
    
    public init(subscription: EventSubscription, eventBus: EventBus) {
        self.subscription = subscription
        self.eventBus = eventBus
    }
    
    public func cancel() {
        Task {
            await eventBus.unsubscribe(subscription)
        }
    }
}

// MARK: - EventBus extensions for convenience

public extension EventBus {
    /// Subscribe with automatic subscription management
    func on<E: PluginEvent>(
        _ eventType: E.Type,
        handler: @escaping @Sendable (E) async -> Void
    ) async -> TypedEventSubscription<E> {
        let sub = subscribe(to: eventType, handler: handler)
        return TypedEventSubscription(subscription: sub, eventBus: self)
    }
    
    /// Publish multiple events
    func publishBatch<E: PluginEvent>(_ events: [E]) async {
        for event in events {
            await publish(event)
        }
    }
}
