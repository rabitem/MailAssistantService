//
//  AIProviderSettings.swift
//  KimiMailAssistant
//
//  AI provider configuration with secure keychain storage.
//

import SwiftUI
import Security

struct AIProviderSettings: View {
    @AppStorage("selectedProvider") private var selectedProvider = AIProvider.kimi
    @AppStorage("selectedModel") private var selectedModel = "kimi-k2.5"
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("maxTokens") private var maxTokens = 4096
    @AppStorage("enableStreaming") private var enableStreaming = true
    @AppStorage("contextWindow") private var contextWindow = 5
    @AppStorage("customEndpoint") private var customEndpoint = ""
    
    @State private var apiKey: String = ""
    @State private var isKeyVisible = false
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionTestStatus?
    @State private var showingAdvancedOptions = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 20) {
                    // Provider Selection
                    Picker("AI Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Label(provider.displayName, systemImage: provider.icon)
                                .tag(provider)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: selectedProvider) { oldValue, newValue in
                        loadAPIKey()
                        updateDefaultModel(for: newValue)
                    }
                    
                    // Provider Description
                    Text(selectedProvider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Provider")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if isKeyVisible {
                            TextField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        
                        Button {
                            copyKeyFromClipboard()
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("Paste from clipboard")
                    }
                    
                    HStack {
                        Link("Get API Key", destination: selectedProvider.apiKeyURL)
                            .font(.caption)
                        
                        Spacer()
                        
                        if isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        } else if let status = connectionStatus {
                            HStack(spacing: 4) {
                                Image(systemName: status.icon)
                                Text(status.message)
                            }
                            .font(.caption)
                            .foregroundStyle(status.color)
                        }
                        
                        Button("Test Connection") {
                            testConnection()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(apiKey.isEmpty)
                    }
                    
                    Text("Your API key is securely stored in the macOS Keychain and never leaves your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("API Key")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(selectedProvider.availableModels, id: \.self) { model in
                            Text(modelDisplayName(model)).tag(model)
                        }
                    }
                    
                    if selectedProvider == .ollama || selectedProvider == .custom {
                        TextField("Custom Endpoint URL", text: $customEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Toggle("Enable streaming responses", isOn: $enableStreaming)
                    
                    DisclosureGroup("Advanced Options", isExpanded: $showingAdvancedOptions) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Temperature: \(String(format: "%.1f", temperature))")
                                    Spacer()
                                    Text(temperatureDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $temperature, in: 0...2, step: 0.1)
                                Text("Lower values make output more focused and deterministic. Higher values make it more creative.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max Tokens: \(maxTokens)")
                                Slider(value: Binding(
                                    get: { Double(maxTokens) },
                                    set: { maxTokens = Int($0) }
                                ), in: 256...8192, step: 256)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Context Window: \(contextWindow) emails")
                                Slider(value: Binding(
                                    get: { Double(contextWindow) },
                                    set: { contextWindow = Int($0) }
                                ), in: 1...20, step: 1)
                                Text("Number of previous emails to include for context.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            } header: {
                Text("Model Settings")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    ModelCapabilityRow(
                        feature: "Email Analysis",
                        supported: selectedProvider.supportsAnalysis,
                        description: "AI-powered email categorization and summarization"
                    )
                    ModelCapabilityRow(
                        feature: "Reply Generation",
                        supported: selectedProvider.supportsReply,
                        description: "Smart draft generation with context awareness"
                    )
                    ModelCapabilityRow(
                        feature: "Local Processing",
                        supported: selectedProvider.supportsLocal,
                        description: "Process emails on-device without cloud"
                    )
                }
            } header: {
                Text("Capabilities")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAPIKey()
        }
        .onDisappear {
            saveAPIKey()
        }
    }
    
    // MARK: - Computed Properties
    
    private var temperatureDescription: String {
        switch temperature {
        case 0..<0.3: return "Focused"
        case 0.3..<0.7: return "Balanced"
        case 0.7..<1.2: return "Creative"
        default: return "Very Creative"
        }
    }
    
    // MARK: - Methods
    
    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "kimi-k2.5": return "Kimi K2.5"
        case "gpt-4o": return "GPT-4o"
        case "gpt-4o-mini": return "GPT-4o Mini"
        case "claude-3-5-sonnet": return "Claude 3.5 Sonnet"
        case "claude-3-haiku": return "Claude 3 Haiku"
        default: return model
        }
    }
    
    private func updateDefaultModel(for provider: AIProvider) {
        selectedModel = provider.availableModels.first ?? ""
    }
    
    private func loadAPIKey() {
        apiKey = KeychainManager.shared.getAPIKey(for: selectedProvider) ?? ""
    }
    
    private func saveAPIKey() {
        if !apiKey.isEmpty {
            KeychainManager.shared.setAPIKey(apiKey, for: selectedProvider)
        }
    }
    
    private func copyKeyFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            apiKey = string
        }
    }
    
    private func testConnection() {
        saveAPIKey()
        isTestingConnection = true
        connectionStatus = nil
        
        Task {
            do {
                let service = AIService(provider: selectedProvider, apiKey: apiKey)
                try await service.testConnection()
                await MainActor.run {
                    connectionStatus = .success
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .failed(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }
}

// MARK: - Model Capability Row

struct ModelCapabilityRow: View {
    let feature: String
    let supported: Bool
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Connection Test Status

enum ConnectionTestStatus {
    case success
    case failed(String)
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    var message: String {
        switch self {
        case .success: return "Connected"
        case .failed(let error): return error
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .failed: return .red
        }
    }
}

// MARK: - AI Provider Enum

enum AIProvider: String, CaseIterable, Identifiable {
    case kimi = "kimi"
    case openai = "openai"
    case anthropic = "anthropic"
    case ollama = "ollama"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .kimi: return "Kimi"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .ollama: return "Ollama (Local)"
        case .custom: return "Custom Endpoint"
        }
    }
    
    var icon: String {
        switch self {
        case .kimi: return "sparkles"
        case .openai: return "brain"
        case .anthropic: return "shield"
        case .ollama: return "cpu"
        case .custom: return "network"
        }
    }
    
    var description: String {
        switch self {
        case .kimi:
            return "Kimi's K2.5 model with 256K context window. Best for long emails and document analysis."
        case .openai:
            return "GPT-4o and GPT-4o Mini models. Fast and reliable for most email tasks."
        case .anthropic:
            return "Claude 3.5 Sonnet with advanced reasoning. Great for complex email workflows."
        case .ollama:
            return "Run AI models locally on your Mac. Completely private but requires setup."
        case .custom:
            return "Connect to any OpenAI-compatible API endpoint."
        }
    }
    
    var apiKeyURL: URL {
        switch self {
        case .kimi:
            return URL(string: "https://platform.moonshot.cn/console/api-keys")!
        case .openai:
            return URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")!
        case .ollama:
            return URL(string: "https://ollama.com")!
        case .custom:
            return URL(string: "about:blank")!
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .kimi:
            return ["kimi-k2.5"]
        case .openai:
            return ["gpt-4o", "gpt-4o-mini"]
        case .anthropic:
            return ["claude-3-5-sonnet", "claude-3-haiku"]
        case .ollama:
            return ["llama3.2", "mistral", "mixtral"]
        case .custom:
            return ["custom"]
        }
    }
    
    var supportsAnalysis: Bool { true }
    var supportsReply: Bool { true }
    var supportsLocal: Bool { self == .ollama }
}

// MARK: - Keychain Manager

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func setAPIKey(_ key: String, for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "api_key_\(provider.rawValue)",
            kSecAttrService as String: "com.kimimailassistant.apikeys",
            kSecValueData as String: key.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getAPIKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "api_key_\(provider.rawValue)",
            kSecAttrService as String: "com.kimimailassistant.apikeys",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteAPIKey(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "api_key_\(provider.rawValue)",
            kSecAttrService as String: "com.kimimailassistant.apikeys"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - AI Service Placeholder

class AIService {
    let provider: AIProvider
    let apiKey: String
    
    init(provider: AIProvider, apiKey: String) {
        self.provider = provider
        self.apiKey = apiKey
    }
    
    func testConnection() async throws {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        // Placeholder - actual implementation would make real API call
        if apiKey.count < 10 {
            throw AIError.invalidAPIKey
        }
    }
}

enum AIError: Error {
    case invalidAPIKey
    case networkError
    case rateLimited
}
