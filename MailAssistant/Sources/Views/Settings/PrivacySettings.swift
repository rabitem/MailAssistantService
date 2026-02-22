//
//  PrivacySettings.swift
//  MailAssistant
//
//  Privacy and security settings view.
//

import SwiftUI

struct PrivacySettings: View {
    @AppStorage("localOnlyMode") private var localOnlyMode = false
    @AppStorage("piiRedactionEnabled") private var piiRedactionEnabled = true
    @AppStorage("autoDeleteHistory") private var autoDeleteHistory = 30
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false
    @AppStorage("crashReportingEnabled") private var crashReportingEnabled = true
    @AppStorage("securePasteboard") private var securePasteboard = true
    @AppStorage("screenshotPrevention") private var screenshotPrevention = false
    
    @State private var showingClearDataConfirmation = false
    @State private var showingExportConfirmation = false
    @State private var dataSize: String = "Calculating..."
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Local-only mode", isOn: $localOnlyMode)
                    
                    if localOnlyMode {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            Text("All processing happens on your device. No data sent to external services.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 4)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Email content is sent to your selected AI provider for processing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                }
            } header: {
                Text("Processing Mode")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Automatically redact PII", isOn: $piiRedactionEnabled)
                    
                    if piiRedactionEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Redacted information:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            PIITypeGrid()
                        }
                        .padding(.leading, 4)
                    }
                }
            } header: {
                Text("PII Redaction")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Auto-delete history", selection: $autoDeleteHistory) {
                        Text("Never").tag(0)
                        Text("After 7 days").tag(7)
                        Text("After 30 days").tag(30)
                        Text("After 90 days").tag(90)
                    }
                    
                    Toggle("Enable analytics", isOn: $analyticsEnabled)
                    
                    Toggle("Enable crash reporting", isOn: $crashReportingEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analytics and crash reports help us improve the app. No email content or personal data is ever included.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Data Retention")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Secure pasteboard", isOn: $securePasteboard)
                    
                    if securePasteboard {
                        Text("Clears pasteboard 2 minutes after copying sensitive data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Toggle("Prevent screenshots", isOn: $screenshotPrevention)
                    
                    if screenshotPrevention {
                        Text("Adds screen capture protection to email previews. Some apps may not respect this setting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Security")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local Data")
                                .font(.system(size: 13, weight: .medium))
                            Text(dataSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Export Data...") {
                            showingExportConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Divider()
                    
                    Button("Clear All Data...") {
                        showingClearDataConfirmation = true
                    }
                    .foregroundStyle(.red)
                    
                    Text("This will remove all cached emails, analysis history, and settings. This action cannot be undone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Data Management")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PrivacyInfoRow(
                        icon: "lock.shield",
                        title: "End-to-End Encryption",
                        description: "All data at rest is encrypted using your device's hardware security."
                    )
                    
                    PrivacyInfoRow(
                        icon: "eye.slash",
                        title: "No Training Data",
                        description: "Your emails are never used to train AI models."
                    )
                    
                    PrivacyInfoRow(
                        icon: "server.rack",
                        title: "On-Device Processing",
                        description: "When possible, analysis happens locally on your Mac."
                    )
                }
            } header: {
                Text("Privacy Guarantees")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            calculateDataSize()
        }
        .alert("Clear All Data?", isPresented: $showingClearDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all cached emails, analysis history, and local settings. Your actual emails in Mail.app will not be affected.")
        }
        .alert("Export Data", isPresented: $showingExportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Export") {
                exportData()
            }
        } message: {
            Text("Export your data as a JSON file. This includes your settings and analysis history, but not your actual emails.")
        }
    }
    
    // MARK: - Methods
    
    private func calculateDataSize() {
        // Calculate cache directory size
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheURL = paths.first?.appendingPathComponent("MailAssistant") else {
            dataSize = "0 MB"
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [.fileSizeKey])
            let totalSize = files.reduce(0) { size, url in
                (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 + size
            }
            dataSize = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        } catch {
            dataSize = "0 MB"
        }
    }
    
    private func clearAllData() {
        // Clear UserDefaults (except onboarding status)
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        guard let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.set(onboardingCompleted, forKey: "hasCompletedOnboarding")
        
        // Clear cache directory
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        if let cacheURL = paths.first?.appendingPathComponent("MailAssistant") {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        
        calculateDataSize()
    }
    
    private func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MailAssistant-Data-Export.json"
        panel.allowedContentTypes = [.json]
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        // Collect non-sensitive settings
        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "settings": [
                "localOnlyMode": localOnlyMode,
                "piiRedactionEnabled": piiRedactionEnabled,
                "autoDeleteHistory": autoDeleteHistory,
                "analyticsEnabled": analyticsEnabled,
                "crashReportingEnabled": crashReportingEnabled
            ]
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            try data.write(to: url)
        } catch {
            print("Failed to export data: \(error)")
        }
    }
}

// MARK: - PII Type Grid

struct PIITypeGrid: View {
    let piiTypes = [
        ("Credit Card", "creditcard.fill"),
        ("SSN", "number"),
        ("Phone", "phone.fill"),
        ("Address", "house.fill"),
        ("Email", "envelope.fill"),
        ("Name", "person.fill")
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
            ForEach(piiTypes, id: \.0) { type in
                HStack(spacing: 6) {
                    Image(systemName: type.1)
                        .font(.caption2)
                    Text(type.0)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
}

// MARK: - Privacy Info Row

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    @State private var mailAccessGranted = false
    @State private var accessibilityGranted = false
    @State private var notificationGranted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Required Permissions")
                .font(.headline)
            
            PermissionRow(
                icon: "envelope",
                title: "Mail Access",
                description: "Read and analyze your emails",
                isGranted: mailAccessGranted,
                action: requestMailAccess
            )
            
            PermissionRow(
                icon: "accessibility",
                title: "Accessibility",
                description: "Interact with Mail.app interface",
                isGranted: accessibilityGranted,
                action: requestAccessibility
            )
            
            PermissionRow(
                icon: "bell",
                title: "Notifications",
                description: "Alert you about important emails",
                isGranted: notificationGranted,
                action: requestNotifications
            )
        }
        .padding()
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        // Check current permission states
        mailAccessGranted = false // Check actual Mail.app permissions
        accessibilityGranted = AXIsProcessTrusted()
        notificationGranted = false // Check notification center settings
    }
    
    private func requestMailAccess() {
        // Request Mail.app scripting permission
    }
    
    private func requestAccessibility() {
        let prompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [prompt: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationGranted = granted
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
