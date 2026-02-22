//
//  SuggestionPanel.swift
//  MailExtension
//

import SwiftUI
import MailKit

/// Main suggestion panel for displaying AI-generated responses
struct SuggestionPanel: View {
    @ObservedObject var viewModel: SuggestionViewModel
    @State private var selectedVariant: UUID?
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader
            
            Divider()
            
            // Content based on state
            contentView
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .frame(minWidth: 400, maxWidth: 600)
    }
    
    // MARK: - Header
    
    private var panelHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Kimi Suggestions")
                    .font(.system(size: 13, weight: .semibold))
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if viewModel.state.isLoading {
                    LoadingIndicator()
                        .frame(width: 16, height: 16)
                }
                
                Menu {
                    Button("Settings...") {
                        viewModel.showSettings()
                    }
                    Divider()
                    Button("Help") {
                        viewModel.showHelp()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle:
            IdleView(onGenerate: {
                viewModel.generateSuggestions()
            })
            
        case .analyzing:
            LoadingStateView(message: "Analyzing email context...")
            
        case .generating(let progress):
            LoadingStateView(message: "Generating responses...", progress: progress)
            
        case .completed(let responses):
            SuggestionsListView(
                responses: responses,
                selectedVariant: $selectedVariant,
                isExpanded: $isExpanded,
                onAccept: { response in
                    viewModel.acceptSuggestion(response)
                },
                onEdit: { response in
                    viewModel.editSuggestion(response)
                },
                onRegenerate: {
                    viewModel.regenerateSuggestions()
                },
                onDismiss: {
                    viewModel.dismissSuggestions()
                }
            )
            
        case .error(let message):
            ErrorView(message: message) {
                viewModel.generateSuggestions()
            }
        }
    }
}

// MARK: - Idle View

struct IdleView: View {
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 32))
                .foregroundStyle(.purple.opacity(0.6))
            
            Text("Ready to help you write")
                .font(.system(size: 13, weight: .medium))
            
            Text("Generate AI-powered response suggestions based on the email context")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            
            Button("Generate Suggestions") {
                onGenerate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String
    var progress: Double?
    
    var body: some View {
        VStack(spacing: 16) {
            if let progress = progress {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .frame(width: 32, height: 32)
            } else {
                LoadingIndicator()
                    .frame(width: 32, height: 32)
            }
            
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Loading Indicator

struct LoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.purple.opacity(0.2), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.purple, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            
            Text("Something went wrong")
                .font(.system(size: 13, weight: .medium))
            
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }
}

// MARK: - View Model

@MainActor
class SuggestionViewModel: ObservableObject {
    @Published var state: GenerationState = .idle
    @Published var selectedTone: ResponseTone = .professional
    @Published var selectedLength: ResponseLength = .standard
    @Published var selectedProfile: StyleProfile = .default
    
    private let xpcService: XPCServiceProtocol
    private var currentRequest: GenerationRequest?
    weak var composeSession: MEComposeSession?
    
    init(xpcService: XPCServiceProtocol = XPCServiceConnection.shared.getService() ?? MockXPCService.shared) {
        self.xpcService = xpcService
    }
    
    func generateSuggestions() {
        guard let session = composeSession else { return }
        
        state = .analyzing
        
        let request = createGenerationRequest(for: session)
        currentRequest = request
        
        // Simulate progress
        state = .generating(progress: 0.3)
        
        xpcService.generateResponses(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let responses):
                    self?.state = .completed(responses)
                case .failure(let error):
                    self?.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    func regenerateSuggestions() {
        // Add previous responses to avoid repetition
        generateSuggestions()
    }
    
    func acceptSuggestion(_ response: GeneratedResponse) {
        // Insert into compose session
        NotificationCenter.default.post(
            name: .insertSuggestion,
            object: nil,
            userInfo: ["response": response]
        )
        dismissSuggestions()
    }
    
    func editSuggestion(_ response: GeneratedResponse) {
        // Open in editor
        NotificationCenter.default.post(
            name: .editSuggestion,
            object: nil,
            userInfo: ["response": response]
        )
    }
    
    func dismissSuggestions() {
        state = .idle
    }
    
    func showSettings() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }
    
    func showHelp() {
        NotificationCenter.default.post(name: .showHelp, object: nil)
    }
    
    private func createGenerationRequest(for session: MEComposeSession) -> GenerationRequest {
        let message = session.message
        
        return GenerationRequest(
            emailContent: EmailContent(
                subject: message.subject,
                body: message.plainTextBody ?? "",
                sender: message.sender?.formatted ?? "",
                recipients: message.toAddresses.map { $0.formatted },
                threadMessages: nil,
                attachments: nil
            ),
            tone: selectedTone,
            length: selectedLength,
            styleProfile: selectedProfile,
            previousResponses: nil,
            context: .init(
                isReply: session.mailboxURL?.absoluteString.contains("reply") ?? false,
                isForward: session.mailboxURL?.absoluteString.contains("forward") ?? false,
                threadCount: 1,
                urgencyIndicators: [],
                actionItems: []
            )
        )
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let insertSuggestion = Notification.Name("com.rabitem.KimiMailAssistant.insertSuggestion")
    static let editSuggestion = Notification.Name("com.rabitem.KimiMailAssistant.editSuggestion")
    static let showSettings = Notification.Name("com.rabitem.KimiMailAssistant.showSettings")
    static let showHelp = Notification.Name("com.rabitem.KimiMailAssistant.showHelp")
}
