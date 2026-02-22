//
//  OnboardingWindow.swift
//  MailAssistant
//
//  First-run onboarding window with step-by-step setup.
//

import SwiftUI

struct OnboardingWindow: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isAnimating = false
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case mailAccess = 1
        case aiSetup = 2
        case importEmails = 3
        case complete = 4
        
        var progress: Double {
            Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: currentStep.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 40)
                    .padding(.top, 24)
                
                // Step Indicators
                HStack(spacing: 8) {
                    ForEach(OnboardingStep.allCases, id: \.self) { step in
                        Circle()
                            .fill(stepIndicatorColor(for: step))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 12)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeView(onContinue: { advanceStep() })
                        .tag(OnboardingStep.welcome)
                    
                    MailAccessView(
                        onContinue: { advanceStep() },
                        onBack: { goBack() }
                    )
                    .tag(OnboardingStep.mailAccess)
                    
                    AISetupView(
                        onContinue: { advanceStep() },
                        onBack: { goBack() }
                    )
                    .tag(OnboardingStep.aiSetup)
                    
                    ImportView(
                        onComplete: { completeOnboarding() },
                        onBack: { goBack() },
                        onSkip: { skipImport() }
                    )
                    .tag(OnboardingStep.importEmails)
                    
                    OnboardingCompleteView(onFinish: { finishOnboarding() })
                        .tag(OnboardingStep.complete)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(width: 700, height: 550)
        .fixedSize()
    }
    
    private func stepIndicatorColor(for step: OnboardingStep) -> Color {
        if step.rawValue <= currentStep.rawValue {
            return .blue
        }
        return .gray.opacity(0.3)
    }
    
    private func advanceStep() {
        guard currentStep.rawValue < OnboardingStep.allCases.count - 1 else { return }
        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1)!
        }
    }
    
    private func goBack() {
        guard currentStep.rawValue > 0 else { return }
        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1)!
        }
    }
    
    private func skipImport() {
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        withAnimation {
            currentStep = .complete
        }
    }
    
    private func finishOnboarding() {
        appState.completeOnboarding()
    }
}

// MARK: - Navigation Helpers

struct OnboardingNavigationButtons: View {
    let onContinue: () -> Void
    var onBack: (() -> Void)?
    var continueTitle: String = "Continue"
    var isContinueDisabled: Bool = false
    var showSkip: Bool = false
    var onSkip: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            if let onBack = onBack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
            }
            
            if showSkip, let onSkip = onSkip {
                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(.borderless)
                
                Spacer()
            }
            
            Spacer()
            
            Button(continueTitle) {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isContinueDisabled)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 24)
    }
}

struct OnboardingContentWrapper<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Complete View

struct OnboardingCompleteView: View {
    let onFinish: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.green)
                    .scaleEffect(isAnimating ? 1 : 0)
            }
            .scaleEffect(isAnimating ? 1 : 0.5)
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                
                Text("MailAssistant is ready to help you manage your emails smarter.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "wand.and.stars", text: "AI-powered email analysis")
                FeatureRow(icon: "puzzlepiece", text: "Smart plugin system")
                FeatureRow(icon: "lock.shield", text: "Privacy-first design")
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            Spacer()
            
            Button("Get Started") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
        }
    }
}
