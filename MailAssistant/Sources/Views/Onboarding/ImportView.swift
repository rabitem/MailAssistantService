//
//  ImportView.swift
//  MailAssistant
//
//  Email import and initial indexing view.
//

import SwiftUI

struct ImportView: View {
    let onComplete: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    
    @State private var importStatus: ImportStatus = .notStarted
    @State private importProgress: Double = 0
    @State private var processedEmails = 0
    @State private var totalEmails = 0
    @State private var importScope: ImportScope = .recent
    @State private var enableAutoAnalysis = true
    
    enum ImportStatus {
        case notStarted
        case analyzing
        case importing
        case complete
        case error(String)
    }
    
    enum ImportScope: String, CaseIterable, Identifiable {
        case recent = "Last 30 days"
        case threeMonths = "Last 3 months"
        case sixMonths = "Last 6 months"
        case year = "Last year"
        case all = "All emails"
        
        var id: String { rawValue }
        
        var days: Int {
            switch self {
            case .recent: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            case .all: return 3650 // ~10 years
            }
        }
    }
    
    var body: some View {
        OnboardingContentWrapper(
            title: "Import Emails",
            subtitle: "Choose how much of your email history to analyze"
        ) {
            VStack(spacing: 24) {
                Spacer()
                
                if importStatus == .notStarted {
                    // Import Options
                    ImportOptionsCard(
                        importScope: $importScope,
                        enableAutoAnalysis: $enableAutoAnalysis
                    )
                } else {
                    // Import Progress
                    ImportProgressCard(
                        status: importStatus,
                        progress: importProgress,
                        processedEmails: processedEmails,
                        totalEmails: totalEmails
                    )
                }
                
                Spacer()
                
                // Navigation
                if importStatus == .notStarted {
                    OnboardingNavigationButtons(
                        onContinue: { startImport() },
                        onBack: onBack,
                        continueTitle: "Start Import",
                        showSkip: true,
                        onSkip: onSkip
                    )
                } else if importStatus == .complete {
                    HStack {
                        Button("Back") {
                            importStatus = .notStarted
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Continue") {
                            onComplete()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    private func startImport() {
        importStatus = .analyzing
        
        // Simulate analyzing phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            totalEmails = estimateEmailCount()
            importStatus = .importing
            simulateImport()
        }
    }
    
    private func estimateEmailCount() -> Int {
        // Estimate based on scope
        switch importScope {
        case .recent: return 500
        case .threeMonths: return 1500
        case .sixMonths: return 3000
        case .year: return 6000
        case .all: return 15000
        }
    }
    
    private func simulateImport() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            processedEmails += Int.random(in: 5...20)
            importProgress = min(Double(processedEmails) / Double(totalEmails), 1.0)
            
            if processedEmails >= totalEmails {
                timer.invalidate()
                importStatus = .complete
            }
        }
    }
}

// MARK: - Import Options Card

struct ImportOptionsCard: View {
    @Binding var importScope: ImportView.ImportScope
    @Binding var enableAutoAnalysis: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import Scope")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(ImportView.ImportScope.allCases) { scope in
                    ImportScopeRow(
                        scope: scope,
                        isSelected: importScope == scope
                    ) {
                        importScope = scope
                    }
                }
            }
            
            Divider()
            
            Toggle("Enable automatic email analysis", isOn: $enableAutoAnalysis)
            
            if enableAutoAnalysis {
                Text("New emails will be automatically analyzed as they arrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Importing more emails provides better context for AI analysis but takes longer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct ImportScopeRow: View {
    let scope: ImportView.ImportScope
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                
                Text(scope.rawValue)
                    .font(.system(size: 14))
                
                Spacer()
                
                Text(estimatedCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var estimatedCount: String {
        switch scope {
        case .recent: return "~500 emails"
        case .threeMonths: return "~1,500 emails"
        case .sixMonths: return "~3,000 emails"
        case .year: return "~6,000 emails"
        case .all: return "~15,000 emails"
        }
    }
}

// MARK: - Import Progress Card

struct ImportProgressCard: View {
    let status: ImportView.ImportStatus
    let progress: Double
    let processedEmails: Int
    let totalEmails: Int
    
    var body: some View {
        VStack(spacing: 32) {
            // Status Icon
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.blue, .purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                
                VStack {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                    if status == .importing {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    } else if status == .complete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            // Status Text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.headline)
                
                if status == .importing || status == .complete {
                    Text("\(processedEmails.formatted()) of \(totalEmails.formatted()) emails")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if status == .analyzing {
                    Text("Scanning your Mail.app folders...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Details
            if status == .importing {
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(icon: "envelope", text: "Indexing metadata")
                    DetailRow(icon: "tag", text: "Extracting categories")
                    DetailRow(icon: "person", text: "Building contact graph")
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var statusTitle: String {
        switch status {
        case .notStarted: return "Ready to Import"
        case .analyzing: return "Analyzing..."
        case .importing: return "Importing Emails..."
        case .complete: return "Import Complete!"
        case .error(let message): return "Error: \(message)"
        }
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - Number Formatter

extension Int {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}
