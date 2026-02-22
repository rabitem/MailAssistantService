//
//  WelcomeView.swift
//  MailAssistant
//
//  Welcome screen for first-run onboarding.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        OnboardingContentWrapper(
            title: "Welcome to MailAssistant",
            subtitle: "Your intelligent email companion powered by AI"
        ) {
            VStack(spacing: 32) {
                Spacer()
                
                // Animated Icon
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                        .frame(width: 180, height: 180)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                    
                    // Middle ring
                    Circle()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                    
                    // Inner icon container
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(isAnimating ? 1 : 0.5)
                }
                
                // Features
                VStack(spacing: 16) {
                    FeatureHighlight(
                        icon: "brain.head.profile",
                        title: "AI-Powered Analysis",
                        description: "Smart categorization and priority detection"
                    )
                    
                    FeatureHighlight(
                        icon: "puzzlepiece.fill",
                        title: "Extensible Plugins",
                        description: "Customize with powerful automation tools"
                    )
                    
                    FeatureHighlight(
                        icon: "lock.shield.fill",
                        title: "Privacy First",
                        description: "Your data stays on your device"
                    )
                }
                
                Spacer()
                
                // Continue Button
                Button("Get Started") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
                // Privacy Note
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.caption)
                    Text("Your privacy is our priority. No email content is stored on our servers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Feature Highlight

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: 320)
    }
}
