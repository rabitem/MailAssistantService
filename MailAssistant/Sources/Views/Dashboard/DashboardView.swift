//
//  DashboardView.swift
//  MailAssistant
//
//  Main dashboard with email stats, plugin status, and quick actions.
//

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingQuickActionMenu = false
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "Today"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                DashboardHeader(
                    unreadCount: appState.unreadCount,
                    analyzedCount: appState.analyzedCount,
                    timeRange: $selectedTimeRange
                )
                
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Unread",
                        value: "\(appState.unreadCount)",
                        trend: "+12%",
                        trendUp: true,
                        icon: "envelope.badge",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Analyzed",
                        value: "\(appState.analyzedCount)",
                        trend: "+5%",
                        trendUp: true,
                        icon: "brain.head.profile",
                        color: .purple
                    )
                    
                    StatCard(
                        title: "Replied",
                        value: "\(appState.repliedCount)",
                        trend: "-2%",
                        trendUp: false,
                        icon: "arrowshape.turn.up.left",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Time Saved",
                        value: "\(appState.timeSaved)m",
                        trend: "+18%",
                        trendUp: true,
                        icon: "clock.badge.checkmark",
                        color: .orange
                    )
                }
                
                // Main Content
                HStack(alignment: .top, spacing: 24) {
                    // Left Column
                    VStack(spacing: 24) {
                        ActivityChart(timeRange: selectedTimeRange)
                        RecentActivityList(activities: appState.recentActivities)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right Column
                    VStack(spacing: 24) {
                        PluginStatusCard(plugins: appState.enabledPlugins)
                        QuickActionsCard(actions: quickActions)
                        AISummaryCard(summary: appState.dailySummary)
                    }
                    .frame(width: 300)
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    private var quickActions: [QuickAction] {
        [
            QuickAction(id: "analyze", title: "Analyze Inbox", icon: "brain", color: .purple),
            QuickAction(id: "draft", title: "New Draft", icon: "square.and.pencil", color: .blue),
            QuickAction(id: "rules", title: "Edit Rules", icon: "list.bullet", color: .orange),
            QuickAction(id: "settings", title: "Settings", icon: "gear", color: .gray)
        ]
    }
}

// MARK: - Dashboard Header

struct DashboardHeader: View {
    let unreadCount: Int
    let analyzedCount: Int
    @Binding var timeRange: DashboardView.TimeRange
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.largeTitle.bold())
                Text(getGreeting())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Picker("Time Range", selection: $timeRange) {
                ForEach(DashboardView.TimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Button {
                // Refresh
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = NSFullUserName().components(separatedBy: " ").first ?? "there"
        
        switch hour {
        case 0..<12: return "Good morning, \(name)"
        case 12..<18: return "Good afternoon, \(name)"
        default: return "Good evening, \(name)"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let trend: String
    let trendUp: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: trendUp ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(trend)
                        .font(.caption)
                }
                .foregroundStyle(trendUp ? .green : .red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((trendUp ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Activity Chart

struct ActivityChart: View {
    let timeRange: DashboardView.TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Email Activity")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 16) {
                    LegendItem(color: .blue, label: "Received")
                    LegendItem(color: .purple, label: "Analyzed")
                    LegendItem(color: .green, label: "Replied")
                }
            }
            
            Chart {
                ForEach(sampleData) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.received)
                    )
                    .foregroundStyle(.blue.opacity(0.6))
                    
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.analyzed)
                    )
                    .foregroundStyle(.purple.opacity(0.8))
                    
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.replied)
                    )
                    .foregroundStyle(.green.opacity(0.8))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let day = value.as(String.self) {
                            Text(day)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var sampleData: [ActivityData] {
        [
            ActivityData(day: "Mon", received: 45, analyzed: 32, replied: 18),
            ActivityData(day: "Tue", received: 52, analyzed: 41, replied: 25),
            ActivityData(day: "Wed", received: 38, analyzed: 28, replied: 15),
            ActivityData(day: "Thu", received: 61, analyzed: 48, replied: 30),
            ActivityData(day: "Fri", received: 55, analyzed: 42, replied: 22),
            ActivityData(day: "Sat", received: 23, analyzed: 18, replied: 8),
            ActivityData(day: "Sun", received: 19, analyzed: 15, replied: 6)
        ]
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActivityData: Identifiable {
    let id = UUID()
    let day: String
    let received: Int
    let analyzed: Int
    let replied: Int
}

// MARK: - Recent Activity List

struct RecentActivityList: View {
    let activities: [DashboardActivity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to history
                }
                .font(.caption)
            }
            
            VStack(spacing: 0) {
                ForEach(activities.prefix(5)) { activity in
                    ActivityListItem(activity: activity)
                    
                    if activity.id != activities.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct ActivityListItem: View {
    let activity: DashboardActivity
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activity.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(activity.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 13))
                Text(activity.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let badge = activity.badge {
                Text(badge)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(activity.color.opacity(0.2))
                    .foregroundStyle(activity.color)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Plugin Status Card

struct PluginStatusCard: View {
    let plugins: [Plugin]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Plugins")
                    .font(.headline)
                
                Spacer()
                
                Text("\(plugins.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(plugins.prefix(4)) { plugin in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        
                        Image(systemName: plugin.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(plugin.name)
                            .font(.system(size: 13))
                        
                        Spacer()
                    }
                }
            }
            
            if plugins.count > 4 {
                Button("View All Plugins") {
                    // Navigate to plugins
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    let actions: [QuickAction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(actions) { action in
                    QuickActionButton(action: action)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    
    var body: some View {
        Button {
            performAction()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundStyle(action.color)
                
                Text(action.title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(action.color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func performAction() {
        switch action.id {
        case "analyze":
            NotificationCenter.default.post(name: .analyzeEmail, object: nil)
        case "draft":
            NotificationCenter.default.post(name: .newDraftRequested, object: nil)
        case "rules":
            break
        case "settings":
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        default:
            break
        }
    }
}

struct QuickAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
}

// MARK: - AI Summary Card

struct AISummaryCard: View {
    let summary: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Daily Summary")
                    .font(.headline)
            }
            
            if let summary = summary {
                Text(summary)
                    .font(.system(size: 13))
                    .lineLimit(5)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No new emails to summarize")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Supporting Types

struct DashboardActivity: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let color: Color
    let timestamp: Date
    let badge: String?
}

// MARK: - AppState Extensions

extension AppStateManager {
    var analyzedCount: Int { 128 }
    var repliedCount: Int { 64 }
    var timeSaved: Int { 45 }
    var recentActivities: [DashboardActivity] {
        [
            DashboardActivity(
                id: UUID(),
                title: "Analyzed 5 marketing emails",
                icon: "brain",
                color: .purple,
                timestamp: Date().addingTimeInterval(-300),
                badge: "High Priority"
            ),
            DashboardActivity(
                id: UUID(),
                title: "Generated reply to John",
                icon: "arrowshape.turn.up.left",
                color: .green,
                timestamp: Date().addingTimeInterval(-900),
                badge: nil
            ),
            DashboardActivity(
                id: UUID(),
                title: "Archived 12 newsletters",
                icon: "archivebox",
                color: .blue,
                timestamp: Date().addingTimeInterval(-1800),
                badge: nil
            ),
            DashboardActivity(
                id: UUID(),
                title: "Flagged suspicious email",
                icon: "exclamationmark.triangle",
                color: .orange,
                timestamp: Date().addingTimeInterval(-3600),
                badge: "Security"
            ),
            DashboardActivity(
                id: UUID(),
                title: "Scheduled follow-up",
                icon: "calendar",
                color: .blue,
                timestamp: Date().addingTimeInterval(-7200),
                badge: nil
            )
        ]
    }
    var dailySummary: String? {
        "You have 3 high-priority emails requiring attention: a meeting request from the product team, a contract review from legal, and a security alert from IT. 12 newsletters have been auto-archived."
    }
}
