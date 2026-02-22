//
//  KimiMailAssistantApp.swift
//  KimiMailAssistant
//
//  Created by KimiMailAssistant
//

import SwiftUI

@main
struct KimiMailAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        // Main Window Group
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    MainWindow()
                        .environmentObject(appState)
                } else {
                    OnboardingWindow()
                        .environmentObject(appState)
                }
            }
            .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        
        // Settings Window
        Settings {
            SettingsContainerView()
                .frame(minWidth: 600, minHeight: 450)
        }
    }
}

// MARK: - Settings Container

struct SettingsContainerView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AIProviderSettings()
                .tabItem {
                    Label("AI Provider", systemImage: "brain")
                }
            
            PrivacySettings()
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
            
            PluginSettings()
                .tabItem {
                    Label("Plugins", systemImage: "puzzlepiece")
                }
            
            KeyboardShortcutsSettings()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .scenePadding()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default preferences
        registerDefaultPreferences()
        
        // Setup menu bar extra if needed
        setupMenuBarExtra()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        XPCServiceManager.shared.disconnect()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Bring window to front when dock icon is clicked
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    private func registerDefaultPreferences() {
        let defaults: [String: Any] = [
            // General
            "launchAtLogin": false,
            "showMenuBarIcon": true,
            "showDockIcon": true,
            "startMinimized": false,
            "autoRefreshInterval": 5,
            "notificationEnabled": true,
            "soundEnabled": true,
            "theme": "system",
            "language": "auto",
            
            // AI
            "selectedProvider": "kimi",
            "selectedModel": "kimi-k2.5",
            "temperature": 0.7,
            "maxTokens": 4096,
            "enableStreaming": true,
            "contextWindow": 5,
            
            // Privacy
            "localOnlyMode": false,
            "piiRedactionEnabled": true,
            "autoDeleteHistory": 30,
            "analyticsEnabled": false,
            "crashReportingEnabled": true,
            "securePasteboard": true,
            "screenshotPrevention": false,
            
            // Features
            "enableAutoSuggest": true,
            "enableAutoAnalysis": true,
            "suggestionDelay": 1.5,
            "enableDebugLogging": false,
            
            // Onboarding
            "hasCompletedOnboarding": false
        ]
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    private func setupMenuBarExtra() {
        // Menu bar extra setup would go here
        // Requires additional implementation for status bar icon
    }
}
