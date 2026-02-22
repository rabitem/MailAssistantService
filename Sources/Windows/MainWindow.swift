//
//  MainWindow.swift
//  KimiMailAssistant
//
//  Main app window with tab-based navigation.
//

import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTab: MainTab = .dashboard
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    
    enum MainTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case inbox = "Inbox"
        case plugins = "Plugins"
        case history = "History"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .inbox: return "tray"
            case .plugins: return "puzzlepiece"
            case .history: return "clock.arrow.circlepath"
            }
        }
        
        var color: Color {
            switch self {
            case .dashboard: return .blue
            case .inbox: return .green
            case .plugins: return .purple
            case .history: return .orange
            }
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            Sidebar(selectedTab: $selectedTab)
                .frame(minWidth: 200)
        } detail: {
            contentView
                .frame(minWidth: 600, minHeight: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("View", selection: $selectedTab) {
                    ForEach(MainTab.allCases) { tab in
                        Image(systemName: tab.icon)
                            .tag(tab)
                            .help(tab.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task { await appState.refreshEmails() }
                    } label: {
                        Label("Refresh Now", systemImage: "arrow.clockwise")
                    }
                    
                    Divider()
                    
                    Button {
                        NotificationCenter.default.post(name: .newDraftRequested, object: nil)
                    } label: {
                        Label("New Draft", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .inbox:
            InboxView()
        case .plugins:
            PluginGalleryView()
        case .history:
            HistoryView()
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Binding var selectedTab: MainWindow.MainTab
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(MainWindow.MainTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            } header: {
                Text("Views")
                    .font(.caption)
                    .textCase(.uppercase)
            }
            
            Section {
                ForEach(appState.favoritePlugins) { plugin in
                    Button {
                        appState.activatePlugin(plugin)
                    } label: {
                        Label(plugin.name, systemImage: plugin.icon)
                    }
                }
            } header: {
                Text("Quick Access")
                    .font(.caption)
                    .textCase(.uppercase)
            }
            
            Section {
                if appState.isAnalyzing {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyzing...")
                            .font(.caption)
                    }
                }
                
                if let status = appState.connectionStatus {
                    HStack {
                        Circle()
                            .fill(statusColor(for: status))
                            .frame(width: 8, height: 8)
                        Text(status.description)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Status")
                    .font(.caption)
                    .textCase(.uppercase)
            }
        }
        .listStyle(.sidebar)
    }
    
    private func statusColor(for status: ConnectionStatus) -> Color {
        switch status {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        case .error: return .orange
        }
    }
}

// MARK: - Placeholder Views

struct InboxView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var searchText = ""
    @State private var selectedFilter: EmailFilter = .all
    
    enum EmailFilter: String, CaseIterable {
        case all = "All"
        case analyzed = "Analyzed"
        case pending = "Pending"
        case flagged = "Flagged"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            HStack {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(EmailFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                Spacer()
                
                SearchField(text: $searchText, placeholder: "Search emails...")
                    .frame(width: 250)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Email List
            List(appState.filteredEmails) { email in
                EmailRow(email: email)
                    .contextMenu {
                        Button("Analyze") {
                            Task { await appState.analyzeEmail(email) }
                        }
                        Button("Generate Reply") {
                            Task { await appState.generateReply(for: email) }
                        }
                        Divider()
                        Button("Mark as Read") {
                            Task { await appState.markAsRead(email) }
                        }
                    }
            }
            .listStyle(.plain)
        }
    }
}

struct EmailRow: View {
    let email: EmailSummary
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status Indicator
            VStack {
                Circle()
                    .fill(email.isAnalyzed ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(email.sender)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(email.receivedDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(email.subject)
                    .font(.system(size: 12))
                    .lineLimit(1)
                
                Text(email.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if !email.tags.isEmpty {
                    HStack {
                        ForEach(email.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PluginGalleryView: View {
    @EnvironmentObject var appState: AppStateManager
    
    let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(appState.availablePlugins) { plugin in
                    PluginCard(plugin: plugin)
                }
            }
            .padding()
        }
    }
}

struct PluginCard: View {
    let plugin: Plugin
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: plugin.icon)
                    .font(.title2)
                    .foregroundStyle(.purple)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.isPluginEnabled(plugin) },
                    set: { _ in appState.togglePlugin(plugin) }
                ))
                .toggleStyle(.switch)
            }
            
            Text(plugin.name)
                .font(.headline)
            
            Text(plugin.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            Spacer()
            
            HStack {
                Text(plugin.version)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.isPluginEnabled(plugin) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(height: 160)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct HistoryView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        List(appState.activityHistory) { activity in
            ActivityRow(activity: activity)
        }
        .listStyle(.plain)
    }
}

struct ActivityRow: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .foregroundStyle(activity.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 13))
                Text(activity.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let result = activity.result {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Search Field

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.delegate = context.coordinator
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.searchFieldDidChange(_:))
        return searchField
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        @objc func searchFieldDidChange(_ sender: NSSearchField) {
            text = sender.stringValue
        }
    }
}

// MARK: - Models

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
