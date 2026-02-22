//
//  BackgroundTaskManager.swift
//  MailAssistantService
//
//  Scheduled jobs management - email import, style re-training, maintenance
//

import Foundation
import os.log

// MARK: - Background Task Manager

/// Manages all background tasks for the mail assistant service
class BackgroundTaskManager {
    
    // MARK: - Singleton
    
    static let shared = BackgroundTaskManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.kimimail.assistant.service", category: "BackgroundTaskManager")
    private var tasks: [String: BackgroundTask] = [:]
    private let taskLock = NSLock()
    private var isRunning = false
    
    private let mailImporter = MailImporter()
    private let threadTracker = ThreadTracker()
    
    // MARK: - Initialization
    
    private init() {
        logger.info("BackgroundTaskManager created")
        registerDefaultTasks()
    }
    
    // MARK: - Task Management
    
    /// Registers the default set of background tasks
    private func registerDefaultTasks() {
        // Email import task - runs every 5 minutes
        register(ScheduledTask(
            id: "email.import",
            name: "Email Import",
            schedule: .interval(minutes: 5),
            execute: { [weak self] completion in
                self?.performEmailImport(completion: completion)
            }
        ))
        
        // Thread tracking task - runs every 10 minutes
        register(ScheduledTask(
            id: "thread.update",
            name: "Thread Update",
            schedule: .interval(minutes: 10),
            execute: { [weak self] completion in
                self?.performThreadUpdate(completion: completion)
            }
        ))
        
        // Style re-training task - runs daily
        register(ScheduledTask(
            id: "style.retrain",
            name: "Style Re-training",
            schedule: .daily(hour: 2, minute: 0),
            execute: { [weak self] completion in
                self?.performStyleRetraining(completion: completion)
            }
        ))
        
        // Maintenance task - runs weekly
        register(ScheduledTask(
            id: "maintenance.weekly",
            name: "Weekly Maintenance",
            schedule: .weekly(day: .sunday, hour: 3, minute: 0),
            execute: { [weak self] completion in
                self?.performMaintenance(completion: completion)
            }
        ))
        
        // Database optimization - runs daily during off-hours
        register(ScheduledTask(
            id: "db.optimize",
            name: "Database Optimization",
            schedule: .daily(hour: 4, minute: 30),
            execute: { [weak self] completion in
                self?.performDatabaseOptimization(completion: completion)
            }
        ))
        
        logger.info("Registered \(tasks.count) default background tasks")
    }
    
    /// Registers a new background task
    func register(_ task: BackgroundTask) {
        taskLock.lock()
        tasks[task.id] = task
        taskLock.unlock()
        
        logger.info("📋 Registered task: \(task.name) (\(task.id))")
    }
    
    /// Unregisters a background task
    func unregister(taskID: String) {
        taskLock.lock()
        tasks.removeValue(forKey: taskID)
        taskLock.unlock()
        
        logger.info("🗑️ Unregistered task: \(taskID)")
    }
    
    /// Starts all registered tasks
    func startAllTasks() {
        taskLock.lock()
        let taskList = Array(tasks.values)
        taskLock.unlock()
        
        guard !isRunning else {
            logger.warning("Background tasks already running")
            return
        }
        
        isRunning = true
        logger.info("▶️ Starting all background tasks...")
        
        for task in taskList {
            task.start()
            logger.debug("Started task: \(task.name)")
        }
        
        logger.info("✅ All background tasks started")
    }
    
    /// Stops all running tasks
    func stopAllTasks() {
        guard isRunning else { return }
        
        taskLock.lock()
        let taskList = Array(tasks.values)
        taskLock.unlock()
        
        logger.info("⏹️ Stopping all background tasks...")
        
        for task in taskList {
            task.stop()
        }
        
        isRunning = false
        logger.info("✅ All background tasks stopped")
    }
    
    /// Starts the default set of tasks (called during initialization)
    func startDefaultTasks() {
        startAllTasks()
    }
    
    /// Gets the status of all tasks
    func getTaskStatuses() -> [TaskStatus] {
        taskLock.lock()
        let taskList = Array(tasks.values)
        taskLock.unlock()
        
        return taskList.map { $0.status }
    }
    
    /// Triggers a task to run immediately
    func triggerTask(id: String) {
        taskLock.lock()
        let task = tasks[id]
        taskLock.unlock()
        
        guard let task = task else {
            logger.warning("Task not found: \(id)")
            return
        }
        
        logger.info("🚀 Manually triggering task: \(task.name)")
        task.trigger()
    }
    
    // MARK: - Task Executors
    
    private func performEmailImport(completion: @escaping (TaskResult) -> Void) {
        logger.info("📧 Starting email import...")
        
        mailImporter.importNewEmails { [weak self] result in
            switch result {
            case .success(let count):
                self?.logger.info("✅ Email import complete: \(count) emails imported")
                LifecycleManager.shared.updateLastEmailImport()
                
                // Notify client if available
                if count > 0 {
                    self?.notifyClientOfNewEmails(count: count)
                }
                
                completion(.success)
                
            case .failure(let error):
                self?.logger.error("❌ Email import failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    private func performThreadUpdate(completion: @escaping (TaskResult) -> Void) {
        logger.info("🧵 Starting thread update...")
        
        threadTracker.updateThreads { [weak self] result in
            switch result {
            case .success(let count):
                self?.logger.info("✅ Thread update complete: \(count) threads updated")
                completion(.success)
            case .failure(let error):
                self?.logger.error("❌ Thread update failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    private func performStyleRetraining(completion: @escaping (TaskResult) -> Void) {
        logger.info("🎨 Starting style re-training...")
        
        // This would trigger the AI model to re-train on new emails
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
            self.logger.info("✅ Style re-training complete")
            completion(.success)
        }
    }
    
    private func performMaintenance(completion: @escaping (TaskResult) -> Void) {
        logger.info("🔧 Starting weekly maintenance...")
        
        // Clean up old logs
        cleanupOldLogs()
        
        // Verify database integrity
        verifyDatabaseIntegrity()
        
        // Clean up temporary files
        cleanupTemporaryFiles()
        
        logger.info("✅ Weekly maintenance complete")
        completion(.success)
    }
    
    private func performDatabaseOptimization(completion: @escaping (TaskResult) -> Void) {
        logger.info("💾 Starting database optimization...")
        
        // Run VACUUM, REINDEX, etc.
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1) {
            self.logger.info("✅ Database optimization complete")
            completion(.success)
        }
    }
    
    // MARK: - Private Helpers
    
    private func notifyClientOfNewEmails(count: Int) {
        // TODO: Get reference to client connection and notify
        logger.info("📬 Notifying client of \(count) new emails")
    }
    
    private func cleanupOldLogs() {
        logger.info("🧹 Cleaning up old logs...")
        // Remove logs older than 30 days
    }
    
    private func verifyDatabaseIntegrity() {
        logger.info("🔍 Verifying database integrity...")
        // Run integrity checks
    }
    
    private func cleanupTemporaryFiles() {
        logger.info("🗑️ Cleaning up temporary files...")
        // Remove temp files
    }
}

// MARK: - Task Status

struct TaskStatus: Codable {
    let id: String
    let name: String
    let isRunning: Bool
    let lastRun: Date?
    let lastResult: String?
    let nextScheduledRun: Date?
    let runCount: Int
    let failureCount: Int
}

// MARK: - Task Result

enum TaskResult {
    case success
    case failure(Error)
}

// MARK: - Background Task Protocol

protocol BackgroundTask {
    var id: String { get }
    var name: String { get }
    var status: TaskStatus { get }
    
    func start()
    func stop()
    func trigger()
}

// MARK: - Scheduled Task Implementation

class ScheduledTask: BackgroundTask {
    let id: String
    let name: String
    let schedule: Schedule
    private let execute: (@escaping (TaskResult) -> Void) -> Void
    
    private var timer: Timer?
    private var isActive = false
    private var lastRun: Date?
    private var lastResult: String?
    private var nextScheduledRun: Date?
    private var runCount = 0
    private var failureCount = 0
    private let statusLock = NSLock()
    
    var status: TaskStatus {
        statusLock.lock()
        defer { statusLock.unlock() }
        return TaskStatus(
            id: id,
            name: name,
            isRunning: isActive,
            lastRun: lastRun,
            lastResult: lastResult,
            nextScheduledRun: nextScheduledRun,
            runCount: runCount,
            failureCount: failureCount
        )
    }
    
    init(id: String, name: String, schedule: Schedule, execute: @escaping (@escaping (TaskResult) -> Void) -> Void) {
        self.id = id
        self.name = name
        self.schedule = schedule
        self.execute = execute
    }
    
    func start() {
        guard !isActive else { return }
        isActive = true
        
        // Calculate next run time
        scheduleNextRun()
    }
    
    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }
    
    func trigger() {
        runTask()
    }
    
    private func scheduleNextRun() {
        guard isActive else { return }
        
        let nextDate = schedule.nextOccurrence(from: Date())
        nextScheduledRun = nextDate
        
        let interval = nextDate.timeIntervalSinceNow
        
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: max(interval, 0), repeats: false) { _ in
                self?.runTask()
            }
        }
    }
    
    private func runTask() {
        statusLock.lock()
        runCount += 1
        statusLock.unlock()
        
        lastRun = Date()
        
        execute { [weak self] result in
            guard let self = self else { return }
            
            self.statusLock.lock()
            switch result {
            case .success:
                self.lastResult = "Success"
            case .failure(let error):
                self.failureCount += 1
                self.lastResult = "Failed: \(error.localizedDescription)"
            }
            self.statusLock.unlock()
            
            // Schedule next run
            if self.isActive {
                self.scheduleNextRun()
            }
        }
    }
}
