//
//  KimiMailAssistantApp.swift
//  KimiMailAssistant
//
//  Main app entry point with menu bar and window group setup.
//

import SwiftUI

@main
struct KimiMailAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    MainWindow()
                } else {
                    OnboardingWindow()
                }
            }
            .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Draft") {
                    NotificationCenter.default.post(name: .newDraftRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            CommandMenu("Plugins") {
                Button("Plugin Store...") {
                    NotificationCenter.default.post(name: .showPluginStore, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Divider()
                
                ForEach(appState.enabledPlugins) { plugin in
                    Button(plugin.name) {
                        appState.activatePlugin(plugin)
                    }
                }
            }
            
            CommandMenu("AI") {
                Button("Analyze Selected Email") {
                    NotificationCenter.default.post(name: .analyzeEmail, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                
                Button("Generate Reply") {
                    NotificationCenter.default.post(name: .generateReply, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsContainerView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestMailPermissionsIfNeeded()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApplication.shared.windows {
                if window.windowNumber > 0 {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
        return true
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        guard AppStateManager.shared.showMenuBarIcon else { return }
        
        statusBarItem = NSStatusBar.shared.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "envelope.badge.shield.half.filled", accessibilityDescription: "KimiMailAssistant")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(AppStateManager.shared)
        )
    }
    
    @objc private func togglePopover() {
        guard let popover = popover, let button = statusBarItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    // MARK: - Permissions
    
    private func requestMailPermissionsIfNeeded() {
        // Initial permission check will be handled by the onboarding flow
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newDraftRequested = Notification.Name("newDraftRequested")
    static let showPluginStore = Notification.Name("showPluginStore")
    static let analyzeEmail = Notification.Name("analyzeEmail")
    static let generateReply = Notification.Name("generateReply")
}

// MARK: - Settings Container

struct SettingsContainerView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case ai = "AI Provider"
        case privacy = "Privacy"
        case plugins = "Plugins"
        case advanced = "Advanced"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .ai: return "cpu"
            case .privacy: return "lock.shield"
            case .plugins: return "puzzlepiece"
            case .advanced: return "gearshape.2"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettings()
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)
            
            AIProviderSettings()
                .tabItem {
                    Label(SettingsTab.ai.rawValue, systemImage: SettingsTab.ai.icon)
                }
                .tag(SettingsTab.ai)
            
            PrivacySettings()
                .tabItem {
                    Label(SettingsTab.privacy.rawValue, systemImage: SettingsTab.privacy.icon)
                }
                .tag(SettingsTab.privacy)
            
            PluginSettings()
                .tabItem {
                    Label(SettingsTab.plugins.rawValue, systemImage: SettingsTab.plugins.icon)
                }
                .tag(SettingsTab.plugins)
        }
        .padding()
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("KimiMailAssistant")
                    .font(.headline)
            }
            
            Divider()
            
            if appState.unreadCount > 0 {
                HStack {
                    Image(systemName: "envelope.badge")
                        .foregroundStyle(.red)
                    Text("\(appState.unreadCount) unread emails")
                        .font(.subheadline)
                }
            }
            
            if let lastScan = appState.lastScanDate {
                Text("Last scan: \(lastScan, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            Button("Open Dashboard") {
                showMainWindow()
            }
            
            Button("Settings...") {
                showSettings()
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
    }
    
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows {
            if window.windowNumber > 0 {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
    
    private func showSettings() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
