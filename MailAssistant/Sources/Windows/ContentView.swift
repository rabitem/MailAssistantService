//
//  ContentView.swift
//  MailAssistant
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $viewModel.selectedSection)
                .frame(minWidth: 200)
        } detail: {
            switch viewModel.selectedSection {
            case .dashboard:
                DashboardView()
            case .plugins:
                PluginManagementView()
            case .aiProviders:
                AIProviderConfigView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("View", selection: $viewModel.selectedSection) {
                    ForEach(AppSection.allCases) { section in
                        Label(section.name, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard, plugins, aiProviders, history, settings
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .plugins: return "Plugins"
        case .aiProviders: return "AI Providers"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .plugins: return "puzzlepiece"
        case .aiProviders: return "brain"
        case .history: return "clock"
        case .settings: return "gear"
        }
    }
}

class MainViewModel: ObservableObject {
    @Published var selectedSection: AppSection = .dashboard
}
