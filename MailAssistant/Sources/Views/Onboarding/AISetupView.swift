//
//  AISetupView.swift
//  MailAssistant
//
//  AI provider configuration during onboarding.
//

import SwiftUI

struct AISetupView: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    
    @State private var selectedProvider: AIProvider = .kimi
    @State private var apiKey: String = ""
    @State private var isKeyVisible = false
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus?
    @State private var showAdvancedOptions = false
    
    enum ConnectionStatus {
        case success
        case failed(String)
    }
    
    var body: some View {
        OnboardingContentWrapper(
            title: "Configure AI",
            subtitle: "Choose your preferred AI provider for email analysis"
        ) {
            VStack(spacing: 20) {
                Spacer()
                
                // Provider Selection
                ProviderSelectionGrid(
                    selectedProvider: $selectedProvider,
                    onSelect: { provider in
                        selectedProvider = provider
                        connectionStatus = nil
                    }
                )
                
                // API Key Input
                APIKeyInputSection(
                    provider: selectedProvider,
                    apiKey: $apiKey,
                    isKeyVisible: $isKeyVisible,
                    connectionStatus: connectionStatus
                )
                
                // Advanced Options
                DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Model", selection: .constant(selectedProvider.availableModels.first ?? "")) {
                            ForEach(selectedProvider.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Temperature: 0.7")
                            Slider(value: .constant(0.7), in: 0...2, step: 0.1)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                // Navigation
                OnboardingNavigationButtons(
                    onContinue: {
                        saveAPIKey()
                        onContinue()
                    },
                    onBack: onBack,
                    isContinueDisabled: apiKey.isEmpty || connectionStatus != .success
                )
            }
        }
    }
    
    private func saveAPIKey() {
        KeychainManager.shared.setAPIKey(apiKey, for: selectedProvider)
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
    }
}

// MARK: - Provider Selection Grid

struct ProviderSelectionGrid: View {
    @Binding var selectedProvider: AIProvider
    let onSelect: (AIProvider) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(AIProvider.allCases.filter { $0 != .custom }) { provider in
                ProviderCard(
                    provider: provider,
                    isSelected: selectedProvider == provider
                ) {
                    onSelect(provider)
                }
            }
        }
    }
}

struct ProviderCard: View {
    let provider: AIProvider
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                
                Image(systemName: provider.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? provider.color : .secondary)
                
                Text(provider.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(provider.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .padding()
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Key Input Section

struct APIKeyInputSection: View {
    let provider: AIProvider
    @Binding var apiKey: String
    @Binding var isKeyVisible: Bool
    let connectionStatus: AISetupView.ConnectionStatus?
    
    @State private var isTesting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API Key")
                    .font(.headline)
                
                Spacer()
                
                Link("Get API Key", destination: provider.apiKeyURL)
                    .font(.caption)
            }
            
            HStack {
                Group {
                    if isKeyVisible {
                        TextField("Enter your API key", text: $apiKey)
                    } else {
                        SecureField("Enter your API key", text: $apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                
                Button {
                    isKeyVisible.toggle()
                } label: {
                    Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
            
            HStack {
                Text("Your API key is stored securely in the macOS Keychain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let status = connectionStatus {
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon(for: status))
                        Text(statusMessage(for: status))
                    }
                    .font(.caption)
                    .foregroundStyle(statusColor(for: status))
                }
                
                Button("Test") {
                    testConnection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(apiKey.isEmpty || isTesting)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private func testConnection() {
        isTesting = true
        // Simulate test
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTesting = false
        }
    }
    
    private func statusIcon(for status: AISetupView.ConnectionStatus) -> String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    private func statusMessage(for status: AISetupView.ConnectionStatus) -> String {
        switch status {
        case .success: return "Connected"
        case .failed(let message): return message
        }
    }
    
    private func statusColor(for status: AISetupView.ConnectionStatus) -> Color {
        switch status {
        case .success: return .green
        case .failed: return .red
        }
    }
}

// MARK: - AI Provider Extensions

extension AIProvider {
    var color: Color {
        switch self {
        case .kimi: return .purple
        case .openai: return .green
        case .anthropic: return .orange
        case .ollama: return .blue
        case .custom: return .gray
        }
    }
    
    var shortDescription: String {
        switch self {
        case .kimi:
            return "256K context window, excellent for long emails"
        case .openai:
            return "Fast and reliable GPT-4o models"
        case .anthropic:
            return "Advanced reasoning with Claude"
        case .ollama:
            return "Run AI locally on your Mac"
        case .custom:
            return "Connect any OpenAI-compatible API"
        }
    }
}
