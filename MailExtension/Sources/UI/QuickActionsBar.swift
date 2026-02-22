//
//  QuickActionsBar.swift
//  MailExtension
//

import SwiftUI

/// Quick actions toolbar for the mail compose window
struct QuickActionsBar: View {
    @ObservedObject var viewModel: QuickActionsViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Main generate button
            GenerateButton(state: viewModel.generationState) {
                viewModel.generateSuggestions()
            }
            
            Divider()
                .frame(height: 20)
            
            // Quick action buttons
            QuickActionButton(
                icon: "text.badge.checkmark",
                tooltip: "Check grammar & tone",
                isLoading: viewModel.isAnalyzing
            ) {
                viewModel.checkGrammarAndTone()
            }
            
            QuickActionButton(
                icon: "text.alignleft",
                tooltip: "Summarize",
                isLoading: viewModel.isSummarizing
            ) {
                viewModel.summarizeThread()
            }
            
            QuickActionButton(
                icon: "wand.and.stars",
                tooltip: "Improve writing",
                isLoading: viewModel.isImproving
            ) {
                viewModel.improveWriting()
            }
            
            Spacer()
            
            // Settings button
            Menu {
                Button {
                    viewModel.openSettings()
                } label: {
                    Label("Settings...", systemImage: "gear")
                }
                
                Divider()
                
                Menu("Tone") {
                    ForEach(ResponseTone.allCases) { tone in
                        Button {
                            viewModel.selectedTone = tone
                        } label: {
                            HStack {
                                Text(tone.displayName)
                                if viewModel.selectedTone == tone {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Menu("Length") {
                    ForEach(ResponseLength.allCases) { length in
                        Button {
                            viewModel.selectedLength = length
                        } label: {
                            HStack {
                                Text(length.displayName)
                                if viewModel.selectedLength == length {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                Button {
                    viewModel.showKeyboardShortcuts()
                } label: {
                    Label("Keyboard Shortcuts", systemImage: "keyboard")
                }
                
                Button {
                    viewModel.showHelp()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Generate Button

struct GenerateButton: View {
    let state: GenerationState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if state.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }
                
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(.purple)
        .disabled(state.isLoading)
        .keyboardShortcut("g", modifiers: [.command, .shift])
    }
    
    private var buttonTitle: String {
        switch state {
        case .idle:
            return "Generate"
        case .analyzing:
            return "Analyzing..."
        case .generating:
            return "Generating..."
        case .completed:
            return "Regenerate"
        case .error:
            return "Try Again"
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let tooltip: String
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                }
            }
            .frame(width: 24, height: 24)
            .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.borderless)
        .disabled(isLoading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(tooltip)
    }
}

// MARK: - View Model

@MainActor
class QuickActionsViewModel: ObservableObject {
    @Published var generationState: GenerationState = .idle
    @Published var selectedTone: ResponseTone = .professional
    @Published var selectedLength: ResponseLength = .standard
    @Published var isAnalyzing = false
    @Published var isSummarizing = false
    @Published var isImproving = false
    
    weak var composeSession: MEComposeSession?
    private let xpcService: XPCServiceProtocol
    
    init(xpcService: XPCServiceProtocol = XPCServiceConnection.shared.getService() ?? MockXPCService.shared) {
        self.xpcService = xpcService
    }
    
    func generateSuggestions() {
        generationState = .analyzing
        
        // Simulate generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.generationState = .generating(progress: 0.0)
            
            // Progress simulation
            var progress: Double = 0.0
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                progress += 0.1
                self.generationState = .generating(progress: progress)
                
                if progress >= 1.0 {
                    timer.invalidate()
                    // Show suggestion panel
                    NotificationCenter.default.post(name: .showSuggestionPanel, object: nil)
                    self.generationState = .idle
                }
            }
        }
    }
    
    func checkGrammarAndTone() {
        isAnalyzing = true
        // Implementation would connect to XPC service
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isAnalyzing = false
            NotificationCenter.default.post(name: .showToneAnalysis, object: nil)
        }
    }
    
    func summarizeThread() {
        isSummarizing = true
        // Implementation would connect to XPC service
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isSummarizing = false
            NotificationCenter.default.post(name: .showSummary, object: nil)
        }
    }
    
    func improveWriting() {
        isImproving = true
        // Implementation would connect to XPC service
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isImproving = false
            NotificationCenter.default.post(name: .showImprovements, object: nil)
        }
    }
    
    func openSettings() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }
    
    func showKeyboardShortcuts() {
        NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
    }
    
    func showHelp() {
        NotificationCenter.default.post(name: .showHelp, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let showSuggestionPanel = Notification.Name("com.rabitem.MailAssistant.showSuggestionPanel")
    static let showToneAnalysis = Notification.Name("com.rabitem.MailAssistant.showToneAnalysis")
    static let showSummary = Notification.Name("com.rabitem.MailAssistant.showSummary")
    static let showImprovements = Notification.Name("com.rabitem.MailAssistant.showImprovements")
    static let showKeyboardShortcuts = Notification.Name("com.rabitem.MailAssistant.showKeyboardShortcuts")
}

// MARK: - Toolbar Extension for AppKit Integration

import AppKit

/// NSView wrapper for SwiftUI QuickActionsBar
class QuickActionsToolbar: NSView {
    private var hostingView: NSHostingView<QuickActionsBar>?
    private var viewModel: QuickActionsViewModel
    
    init(viewModel: QuickActionsViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        self.viewModel = QuickActionsViewModel()
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        let swiftUIView = QuickActionsBar(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: swiftUIView)
        
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        self.hostingView = hostingView
    }
    
    func updateFrame(_ frame: NSRect) {
        self.frame = frame
    }
}

// MARK: - Preview

struct QuickActionsBar_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsBar(viewModel: QuickActionsViewModel())
            .padding()
            .frame(width: 500)
    }
}
