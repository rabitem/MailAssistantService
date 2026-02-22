//
//  GeneralSettings.swift
//  KimiMailAssistant
//
//  General app behavior settings view.
//

import SwiftUI
import ServiceManagement

struct GeneralSettings: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("showDockIcon") private var showDockIcon = true
    @AppStorage("startMinimized") private var startMinimized = false
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 5
    @AppStorage("notificationEnabled") private var notificationEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("theme") private var theme = AppTheme.system
    @AppStorage("language") private var language = "auto"
    
    @State private var showingResetConfirmation = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { oldValue, newValue in
                            Task {
                                await setLaunchAtLogin(newValue)
                            }
                        }
                    
                    Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    
                    Toggle("Show dock icon", isOn: $showDockIcon)
                        .onChange(of: showDockIcon) { oldValue, newValue in
                            updateDockIconVisibility(newValue)
                        }
                    
                    Toggle("Start minimized", isOn: $startMinimized)
                }
            } header: {
                Text("Startup")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Auto-refresh interval", selection: $autoRefreshInterval) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("Manual only").tag(0)
                    }
                    
                    HStack {
                        Toggle("Enable notifications", isOn: $notificationEnabled)
                        
                        if notificationEnabled {
                            Toggle("Play sounds", isOn: $soundEnabled)
                                .padding(.leading, 20)
                        }
                    }
                }
            } header: {
                Text("Behavior")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Appearance", selection: $theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Language", selection: $language) {
                        Text("System Default").tag("auto")
                        Divider()
                        Text("English").tag("en")
                        Text("German").tag("de")
                        Text("French").tag("fr")
                        Text("Spanish").tag("es")
                        Text("Chinese (Simplified)").tag("zh-Hans")
                        Text("Japanese").tag("ja")
                    }
                }
            } header: {
                Text("Appearance")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Button("Export Settings...") {
                        exportSettings()
                    }
                    
                    Button("Import Settings...") {
                        importSettings()
                    }
                    
                    Divider()
                    
                    Button("Reset to Defaults...") {
                        showingResetConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text("Advanced")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Reset Settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    private func setLaunchAtLogin(_ enabled: Bool) async {
        // Note: Requires SMAppService in macOS 13+
        // Implementation depends on app signing and distribution method
    }
    
    private func updateDockIconVisibility(_ visible: Bool) {
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }
    
    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "KimiMailAssistant-Settings.json"
        panel.allowedContentTypes = [.json]
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        let settings: [String: Any] = [
            "launchAtLogin": launchAtLogin,
            "showMenuBarIcon": showMenuBarIcon,
            "showDockIcon": showDockIcon,
            "startMinimized": startMinimized,
            "autoRefreshInterval": autoRefreshInterval,
            "notificationEnabled": notificationEnabled,
            "soundEnabled": soundEnabled,
            "theme": theme.rawValue,
            "language": language
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try data.write(to: url)
        } catch {
            print("Failed to export settings: \(error)")
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let launch = settings?["launchAtLogin"] as? Bool {
                launchAtLogin = launch
            }
            if let menuBar = settings?["showMenuBarIcon"] as? Bool {
                showMenuBarIcon = menuBar
            }
            if let dock = settings?["showDockIcon"] as? Bool {
                showDockIcon = dock
            }
            if let minimized = settings?["startMinimized"] as? Bool {
                startMinimized = minimized
            }
            if let interval = settings?["autoRefreshInterval"] as? Int {
                autoRefreshInterval = interval
            }
            if let notifications = settings?["notificationEnabled"] as? Bool {
                notificationEnabled = notifications
            }
            if let sound = settings?["soundEnabled"] as? Bool {
                soundEnabled = sound
            }
            if let themeValue = settings?["theme"] as? String,
               let newTheme = AppTheme(rawValue: themeValue) {
                theme = newTheme
            }
            if let lang = settings?["language"] as? String {
                language = lang
            }
        } catch {
            print("Failed to import settings: \(error)")
        }
    }
    
    private func resetSettings() {
        launchAtLogin = false
        showMenuBarIcon = true
        showDockIcon = true
        startMinimized = false
        autoRefreshInterval = 5
        notificationEnabled = true
        soundEnabled = true
        theme = .system
        language = "auto"
    }
}

// MARK: - Types

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

// MARK: - Keyboard Shortcuts Settings

struct KeyboardShortcutsSettings: View {
    @AppStorage("shortcutNewDraft") private var shortcutNewDraft = "⇧⌘N"
    @AppStorage("shortcutAnalyze") private var shortcutAnalyze = "⇧⌘A"
    @AppStorage("shortcutGenerateReply") private var shortcutGenerateReply = "⇧⌘R"
    @AppStorage("shortcutQuickAction") private var shortcutQuickAction = "⌃⌘Space"
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    ShortcutRow(title: "New Draft", shortcut: $shortcutNewDraft)
                    ShortcutRow(title: "Analyze Email", shortcut: $shortcutAnalyze)
                    ShortcutRow(title: "Generate Reply", shortcut: $shortcutGenerateReply)
                    ShortcutRow(title: "Quick Action", shortcut: $shortcutQuickAction)
                }
            } header: {
                Text("Global Shortcuts")
                    .font(.headline)
            }
            
            Section {
                Text("Keyboard shortcuts work even when the app is not focused. You can customize them to avoid conflicts with other applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ShortcutRow: View {
    let title: String
    @Binding var shortcut: String
    @State private var isRecording = false
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(shortcut) {
                isRecording.toggle()
            }
            .buttonStyle(.bordered)
            .background(isRecording ? Color.blue.opacity(0.2) : Color.clear)
        }
    }
}
