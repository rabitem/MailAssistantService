//
//  MailAccessView.swift
//  MailAssistant
//
//  Mail.app permission and access setup.
//

import SwiftUI

struct MailAccessView: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    
    @State private var permissionStatus: PermissionStatus = .notRequested
    @State private var selectedAccounts: Set<String> = []
    @State private var availableAccounts: [MailAccount] = []
    @State private var isLoading = false
    
    enum PermissionStatus {
        case notRequested
        case requesting
        case granted
        case denied
    }
    
    var body: some View {
        OnboardingContentWrapper(
            title: "Connect Your Mail",
            subtitle: "Grant access to analyze and enhance your email experience"
        ) {
            VStack(spacing: 24) {
                Spacer()
                
                // Permission Status Card
                PermissionStatusCard(
                    status: permissionStatus,
                    onRequest: requestMailPermission
                )
                
                // Account Selection
                if permissionStatus == .granted {
                    AccountSelectionCard(
                        accounts: availableAccounts,
                        selectedAccounts: $selectedAccounts
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // Navigation
                OnboardingNavigationButtons(
                    onContinue: onContinue,
                    onBack: onBack,
                    isContinueDisabled: permissionStatus != .granted || selectedAccounts.isEmpty
                )
            }
        }
        .onAppear {
            checkExistingPermission()
        }
    }
    
    private func checkExistingPermission() {
        // Check if we already have permission
        // This would check the Mail app scripting permissions
    }
    
    private func requestMailPermission() {
        permissionStatus = .requesting
        
        // Simulate permission request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            permissionStatus = .granted
            loadMailAccounts()
        }
    }
    
    private func loadMailAccounts() {
        isLoading = true
        
        // This would fetch actual accounts from Mail.app
        availableAccounts = [
            MailAccount(id: "work", email: "work@company.com", name: "Work", provider: "Microsoft Exchange"),
            MailAccount(id: "personal", email: "john@gmail.com", name: "Personal", provider: "Gmail"),
            MailAccount(id: "icloud", email: "john@icloud.com", name: "iCloud", provider: "iCloud")
        ]
        
        selectedAccounts = Set(availableAccounts.map(\.id))
        isLoading = false
    }
}

// MARK: - Permission Status Card

struct PermissionStatusCard: View {
    let status: MailAccessView.PermissionStatus
    let onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(statusColor)
            }
            
            // Status Text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Action Button
            if status == .notRequested || status == .denied {
                Button(action: onRequest) {
                    HStack(spacing: 8) {
                        if status == .requesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(status == .denied ? "Open System Settings" : "Grant Access")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(status == .requesting)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var statusIcon: String {
        switch status {
        case .notRequested: return "envelope.badge"
        case .requesting: return "arrow.clockwise"
        case .granted: return "checkmark.shield.fill"
        case .denied: return "xmark.shield"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .notRequested: return .blue
        case .requesting: return .orange
        case .granted: return .green
        case .denied: return .red
        }
    }
    
    private var statusTitle: String {
        switch status {
        case .notRequested: return "Access Required"
        case .requesting: return "Requesting Access..."
        case .granted: return "Access Granted"
        case .denied: return "Access Denied"
        }
    }
    
    private var statusDescription: String {
        switch status {
        case .notRequested:
            return "MailAssistant needs permission to read and analyze your emails from Mail.app"
        case .requesting:
            return "Please approve the permission in the dialog that appears"
        case .granted:
            return "You can now select which accounts to connect below"
        case .denied:
            return "Please enable access in System Settings > Privacy & Security > Automation"
        }
    }
}

// MARK: - Account Selection Card

struct AccountSelectionCard: View {
    let accounts: [MailAccount]
    @Binding var selectedAccounts: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Accounts")
                    .font(.headline)
                
                Spacer()
                
                Button(selectedAccounts.count == accounts.count ? "Deselect All" : "Select All") {
                    if selectedAccounts.count == accounts.count {
                        selectedAccounts.removeAll()
                    } else {
                        selectedAccounts = Set(accounts.map(\.id))
                    }
                }
                .font(.caption)
            }
            
            Text("Choose which email accounts to analyze")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                ForEach(accounts) { account in
                    AccountRow(
                        account: account,
                        isSelected: selectedAccounts.contains(account.id)
                    ) {
                        toggleAccount(account.id)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private func toggleAccount(_ id: String) {
        if selectedAccounts.contains(id) {
            selectedAccounts.remove(id)
        } else {
            selectedAccounts.insert(id)
        }
    }
}

struct AccountRow: View {
    let account: MailAccount
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                // Account icon
                ZStack {
                    Circle()
                        .fill(account.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(String(account.name.prefix(1)))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(account.color)
                }
                
                // Account info
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.system(size: 14, weight: .medium))
                    Text(account.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Provider badge
                Text(account.provider)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mail Account Model

struct MailAccount: Identifiable {
    let id: String
    let email: String
    let name: String
    let provider: String
    
    var color: Color {
        switch provider {
        case "Gmail": return .red
        case "iCloud": return .blue
        case "Microsoft Exchange": return .blue.opacity(0.8)
        case "Outlook": return .blue
        default: return .gray
        }
    }
}
