//
//  SettingsView.swift
//  KimiMailAssistant
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("enableAutoSuggest") private var enableAutoSuggest = true
    @AppStorage("suggestionDelay") private var suggestionDelay = 1.5
    @AppStorage("enableDebugLogging") private var enableDebugLogging = false
    @AppStorage("preferredAIProvider") private var preferredAIProvider = "kimi"
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                enableAutoSuggest: $enableAutoSuggest,
                suggestionDelay: $suggestionDelay
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AIProviderSettingsView(
                preferredAIProvider: $preferredAIProvider
            )
            .tabItem {
                Label("AI Providers", systemImage: "brain")
            }
            
            AdvancedSettingsView(
                enableDebugLogging: $enableDebugLogging
            )
            .tabItem {
                Label("Advanced", systemImage: "wrench")
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct GeneralSettingsView: View {
    @Binding var enableAutoSuggest: Bool
    @Binding var suggestionDelay: Double
    
    var body: some View {
        Form {
            Section("Suggestions") {
                Toggle("Enable Auto-Suggestions", isOn: $enableAutoSuggest)
                
                if enableAutoSuggest {
                    VStack(alignment: .leading) {
                        Text("Suggestion Delay: \(String(format: "%.1f", suggestionDelay))s")
                        Slider(value: $suggestionDelay, in: 0.5...5.0, step: 0.5)
                    }
                }
            }
            
            Section("Keyboard Shortcuts") {
                HStack {
                    Text("Show Suggestions")
                    Spacer()
                    KeyboardShortcutView(shortcut: "⌘ ⇧ K")
                }
                
                HStack {
                    Text("Accept Suggestion")
                    Spacer()
                    KeyboardShortcutView(shortcut: "Tab")
                }
                
                HStack {
                    Text("Dismiss Suggestion")
                    Spacer()
                    KeyboardShortcutView(shortcut: "Esc")
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AIProviderSettingsView: View {
    @Binding var preferredAIProvider: String
    
    let providers = ["kimi", "openai", "anthropic", "local"]
    
    var body: some View {
        Form {
            Section("Default Provider") {
                Picker("AI Provider", selection: $preferredAIProvider) {
                    ForEach(providers, id: \.self) { provider in
                        Text(provider.capitalized)
                            .tag(provider)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            Section("API Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("API Key:") {
                        SecureField("Enter API Key", text: .constant(""))
                            .frame(width: 250)
                    }
                    
                    LabeledContent("Model:") {
                        TextField("Model name", text: .constant("kimi-latest"))
                            .frame(width: 250)
                    }
                    
                    LabeledContent("Max Tokens:") {
                        TextField("4096", text: .constant(""))
                            .frame(width: 100)
                    }
                }
            }
            
            Section("Test Connection") {
                Button("Test API Connection") {
                    // Test connection logic
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AdvancedSettingsView: View {
    @Binding var enableDebugLogging: Bool
    
    var body: some View {
        Form {
            Section("Debug") {
                Toggle("Enable Debug Logging", isOn: $enableDebugLogging)
                
                if enableDebugLogging {
                    HStack {
                        Text("Log Level:")
                        Picker("", selection: .constant("info")) {
                            Text("Error").tag("error")
                            Text("Warning").tag("warning")
                            Text("Info").tag("info")
                            Text("Debug").tag("debug")
                            Text("Verbose").tag("verbose")
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            
            Section("Data") {
                Button("Clear Cache") {
                    // Clear cache logic
                }
                .foregroundStyle(.red)
                
                Button("Export Logs") {
                    // Export logs logic
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct KeyboardShortcutView: View {
    let shortcut: String
    
    var body: some View {
        Text(shortcut)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
    }
}

struct PluginManagementView: View {
    var body: some View {
        Text("Plugin Management")
            .font(.title)
    }
}

struct AIProviderConfigView: View {
    var body: some View {
        Text("AI Provider Configuration")
            .font(.title)
    }
}

struct HistoryView: View {
    var body: some View {
        Text("History")
            .font(.title)
    }
}

struct SidebarView: View {
    @Binding var selection: AppSection
    
    var body: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Label(section.name, systemImage: section.icon)
                .tag(section)
        }
        .listStyle(.sidebar)
    }
}
