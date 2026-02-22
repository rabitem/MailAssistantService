//
//  ScheduledJobs.swift
//  MailAssistantService
//
//  Job definitions and cron-like scheduling for background tasks
//

import Foundation

// MARK: - Schedule Types

/// Defines when a scheduled task should run
indirect enum Schedule {
    /// Run at a specific interval (e.g., every 5 minutes)
    case interval(minutes: Int)
    
    /// Run once daily at a specific time
    case daily(hour: Int, minute: Int)
    
    /// Run weekly on a specific day and time
    case weekly(day: WeekDay, hour: Int, minute: Int)
    
    /// Run monthly on a specific day and time
    case monthly(day: Int, hour: Int, minute: Int)
    
    /// Run on custom cron-like expression
    case cron(CronExpression)
    
    /// Never run automatically (manual trigger only)
    case manual
    
    /// Combine multiple schedules (runs if any match)
    case any([Schedule])
    
    /// Calculate the next occurrence from a given date
    func nextOccurrence(from date: Date) -> Date {
        switch self {
        case .interval(let minutes):
            return date.addingTimeInterval(TimeInterval(minutes * 60))
            
        case .daily(let hour, let minute):
            return nextDailyOccurrence(from: date, hour: hour, minute: minute)
            
        case .weekly(let day, let hour, let minute):
            return nextWeeklyOccurrence(from: date, day: day, hour: hour, minute: minute)
            
        case .monthly(let day, let hour, let minute):
            return nextMonthlyOccurrence(from: date, day: day, hour: hour, minute: minute)
            
        case .cron(let expression):
            return expression.nextOccurrence(from: date)
            
        case .manual:
            // Return a distant future date for manual tasks
            return Date.distantFuture
            
        case .any(let schedules):
            // Return the earliest next occurrence from all schedules
            return schedules
                .map { $0.nextOccurrence(from: date) }
                .min(by: { $0 < $1 }) ?? date.addingTimeInterval(3600)
        }
    }
    
    // MARK: - Private Helpers
    
    private func nextDailyOccurrence(from date: Date, hour: Int, minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard let targetDate = calendar.date(from: components) else {
            return date.addingTimeInterval(86400)
        }
        
        // If target time has already passed today, schedule for tomorrow
        if targetDate <= date {
            return calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate.addingTimeInterval(86400)
        }
        
        return targetDate
    }
    
    private func nextWeeklyOccurrence(from date: Date, day: WeekDay, hour: Int, minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let currentWeekday = calendar.component(.weekday, from: date)
        let targetWeekday = day.calendarComponent
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.weekday = targetWeekday
        
        // Calculate days to add
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd < 0 || (daysToAdd == 0 && isTimePassed(date: date, hour: hour, minute: minute)) {
            daysToAdd += 7
        }
        
        guard let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: calendar.date(from: components) ?? date) else {
            return date.addingTimeInterval(TimeInterval(daysToAdd * 86400))
        }
        
        return targetDate
    }
    
    private func nextMonthlyOccurrence(from date: Date, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = min(day, 28) // Avoid issues with months having fewer days
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard var targetDate = calendar.date(from: components) else {
            return date.addingTimeInterval(30 * 86400)
        }
        
        // If target date has passed, move to next month
        if targetDate <= date {
            targetDate = calendar.date(byAdding: .month, value: 1, to: targetDate) ?? targetDate.addingTimeInterval(30 * 86400)
        }
        
        return targetDate
    }
    
    private func isTimePassed(date: Date, hour: Int, minute: Int) -> Bool {
        var calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return false
        }
        
        if currentHour > hour {
            return true
        } else if currentHour == hour {
            return currentMinute >= minute
        }
        return false
    }
}

// MARK: - Week Day

enum WeekDay: Int, CaseIterable, Codable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var calendarComponent: Int {
        return rawValue
    }
    
    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    var shortName: String {
        return String(name.prefix(3))
    }
}

// MARK: - Cron Expression

/// A simplified cron-like expression parser
/// Format: "minute hour day month weekday"
/// Supports: * (any), specific values, ranges (e.g., 1-5), steps (e.g., */5)
struct CronExpression {
    let minute: CronField
    let hour: CronField
    let dayOfMonth: CronField
    let month: CronField
    let dayOfWeek: CronField
    
    init?(expression: String) {
        let parts = expression.split(separator: " ").map(String.init)
        guard parts.count == 5 else { return nil }
        
        guard let minute = CronField(parts[0], range: 0...59),
              let hour = CronField(parts[1], range: 0...23),
              let dayOfMonth = CronField(parts[2], range: 1...31),
              let month = CronField(parts[3], range: 1...12),
              let dayOfWeek = CronField(parts[4], range: 0...6) else {
            return nil
        }
        
        self.minute = minute
        self.hour = hour
        self.dayOfMonth = dayOfMonth
        self.month = month
        self.dayOfWeek = dayOfWeek
    }
    
    func nextOccurrence(from date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var current = date.addingTimeInterval(60) // Start from next minute
        
        // Limit search to prevent infinite loops
        let maxDate = date.addingTimeInterval(366 * 86400) // One year
        
        while current < maxDate {
            let components = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: current)
            
            guard let min = components.minute,
                  let hr = components.hour,
                  let day = components.day,
                  let mon = components.month,
                  let wday = components.weekday else {
                current = calendar.date(byAdding: .minute, value: 1, to: current) ?? current.addingTimeInterval(60)
                continue
            }
            
            // Convert Sunday from 1->7 to 0
            let adjustedWeekday = wday == 1 ? 0 : wday - 1
            
            if minute.matches(min) &&
               hour.matches(hr) &&
               dayOfMonth.matches(day) &&
               month.matches(mon) &&
               dayOfWeek.matches(adjustedWeekday) {
                return current
            }
            
            current = calendar.date(byAdding: .minute, value: 1, to: current) ?? current.addingTimeInterval(60)
        }
        
        return maxDate
    }
}

// MARK: - Cron Field

/// Represents a single field in a cron expression
enum CronField {
    case any
    case specific(Int)
    case range(ClosedRange<Int>)
    case step(Int, Int?) // step value, optional start
    case list([Int])
    
    init?(_ string: String, range: ClosedRange<Int>) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        
        if trimmed == "*" {
            self = .any
        } else if trimmed.contains(",") {
            // List of values
            let values = trimmed.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard !values.isEmpty else { return nil }
            self = .list(values)
        } else if trimmed.contains("/") {
            // Step expression
            let parts = trimmed.split(separator: "/")
            guard parts.count == 2, let step = Int(parts[1]) else { return nil }
            let start = parts[0] == "*" ? nil : Int(parts[0])
            self = .step(step, start)
        } else if trimmed.contains("-") {
            // Range expression
            let parts = trimmed.split(separator: "-")
            guard parts.count == 2,
                  let start = Int(parts[0]),
                  let end = Int(parts[1]) else { return nil }
            self = .range(start...end)
        } else if let value = Int(trimmed) {
            guard range.contains(value) else { return nil }
            self = .specific(value)
        } else {
            return nil
        }
    }
    
    func matches(_ value: Int) -> Bool {
        switch self {
        case .any:
            return true
        case .specific(let v):
            return v == value
        case .range(let r):
            return r.contains(value)
        case .step(let step, let start):
            let base = start ?? 0
            return (value - base) % step == 0
        case .list(let values):
            return values.contains(value)
        }
    }
}

// MARK: - Job Types

/// Predefined job types for common operations
enum JobType: String, CaseIterable, Codable {
    case emailImport = "email.import"
    case threadUpdate = "thread.update"
    case styleRetraining = "style.retrain"
    case databaseMaintenance = "db.maintenance"
    case databaseOptimization = "db.optimize"
    case logCleanup = "log.cleanup"
    case tempFileCleanup = "temp.cleanup"
    case healthCheck = "health.check"
    
    var defaultSchedule: Schedule {
        switch self {
        case .emailImport:
            return .interval(minutes: 5)
        case .threadUpdate:
            return .interval(minutes: 10)
        case .styleRetraining:
            return .daily(hour: 2, minute: 0)
        case .databaseMaintenance:
            return .weekly(day: .sunday, hour: 3, minute: 0)
        case .databaseOptimization:
            return .daily(hour: 4, minute: 30)
        case .logCleanup:
            return .weekly(day: .monday, hour: 1, minute: 0)
        case .tempFileCleanup:
            return .daily(hour: 3, minute: 0)
        case .healthCheck:
            return .interval(minutes: 15)
        }
    }
    
    var displayName: String {
        switch self {
        case .emailImport:
            return "Email Import"
        case .threadUpdate:
            return "Thread Update"
        case .styleRetraining:
            return "Style Re-training"
        case .databaseMaintenance:
            return "Database Maintenance"
        case .databaseOptimization:
            return "Database Optimization"
        case .logCleanup:
            return "Log Cleanup"
        case .tempFileCleanup:
            return "Temporary File Cleanup"
        case .healthCheck:
            return "Health Check"
        }
    }
    
    var description: String {
        switch self {
        case .emailImport:
            return "Imports new emails from Mail.app"
        case .threadUpdate:
            return "Updates conversation threads"
        case .styleRetraining:
            return "Re-trains AI on writing style"
        case .databaseMaintenance:
            return "Performs database maintenance tasks"
        case .databaseOptimization:
            return "Optimizes database performance"
        case .logCleanup:
            return "Removes old log files"
        case .tempFileCleanup:
            return "Cleans up temporary files"
        case .healthCheck:
            return "Monitors service health"
        }
    }
}

// MARK: - Job Configuration

/// Configuration for a scheduled job
struct JobConfiguration: Codable {
    let id: String
    let type: JobType
    let schedule: Schedule
    let isEnabled: Bool
    let parameters: [String: String]?
    let createdAt: Date
    var lastModifiedAt: Date
}

// MARK: - Schedule Codable

extension Schedule: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, minutes, hour, minute, day, month, weekday, schedules, expression
    }
    
    enum ScheduleType: String, Codable {
        case interval, daily, weekly, monthly, cron, manual, any
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .interval(let minutes):
            try container.encode(ScheduleType.interval, forKey: .type)
            try container.encode(minutes, forKey: .minutes)
            
        case .daily(let hour, let minute):
            try container.encode(ScheduleType.daily, forKey: .type)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
            
        case .weekly(let day, let hour, let minute):
            try container.encode(ScheduleType.weekly, forKey: .type)
            try container.encode(day, forKey: .weekday)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
            
        case .monthly(let day, let hour, let minute):
            try container.encode(ScheduleType.monthly, forKey: .type)
            try container.encode(day, forKey: .day)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
            
        case .cron(let expression):
            try container.encode(ScheduleType.cron, forKey: .type)
            // Store as string representation
            
        case .manual:
            try container.encode(ScheduleType.manual, forKey: .type)
            
        case .any(let schedules):
            try container.encode(ScheduleType.any, forKey: .type)
            try container.encode(schedules, forKey: .schedules)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ScheduleType.self, forKey: .type)
        
        switch type {
        case .interval:
            let minutes = try container.decode(Int.self, forKey: .minutes)
            self = .interval(minutes: minutes)
            
        case .daily:
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .daily(hour: hour, minute: minute)
            
        case .weekly:
            let day = try container.decode(WeekDay.self, forKey: .weekday)
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .weekly(day: day, hour: hour, minute: minute)
            
        case .monthly:
            let day = try container.decode(Int.self, forKey: .day)
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            self = .monthly(day: day, hour: hour, minute: minute)
            
        case .cron:
            self = .manual // Simplified - would need proper cron parsing
            
        case .manual:
            self = .manual
            
        case .any:
            let schedules = try container.decode([Schedule].self, forKey: .schedules)
            self = .any(schedules)
        }
    }
}
