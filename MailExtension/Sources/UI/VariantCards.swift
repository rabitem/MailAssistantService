//
//  VariantCards.swift
//  MailExtension
//

import SwiftUI

/// Cards displaying multiple suggestion variants
struct VariantCards: View {
    let responses: [GeneratedResponse]
    @Binding var selectedVariant: UUID?
    @Binding var isExpanded: Bool
    
    let onSelect: (GeneratedResponse) -> Void
    let onAccept: (GeneratedResponse) -> Void
    let onEdit: (GeneratedResponse) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(responses) { response in
                VariantCard(
                    response: response,
                    isSelected: selectedVariant == response.id,
                    isExpanded: isExpanded && selectedVariant == response.id,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedVariant == response.id {
                                isExpanded.toggle()
                            } else {
                                selectedVariant = response.id
                                isExpanded = true
                                onSelect(response)
                            }
                        }
                    },
                    onAccept: { onAccept(response) },
                    onEdit: { onEdit(response) }
                )
            }
        }
    }
}

// MARK: - Individual Variant Card

struct VariantCard: View {
    let response: GeneratedResponse
    let isSelected: Bool
    let isExpanded: Bool
    
    let onTap: () -> Void
    let onAccept: () -> Void
    let onEdit: () -> Void
    
    @State private var isHovering = false
    
    private var previewText: String {
        if isExpanded {
            return response.text
        }
        let maxLength = 120
        if response.text.count > maxLength {
            return String(response.text.prefix(maxLength)) + "..."
        }
        return response.text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card content
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    // Header with metadata
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: response.tone.icon)
                                .font(.system(size: 10))
                            Text(response.tone.displayName)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Confidence indicator
                        ConfidenceBadge(confidence: response.confidence)
                    }
                    
                    // Preview text
                    Text(previewText)
                        .font(.system(size: 12))
                        .lineLimit(isExpanded ? nil : 3)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .background(cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            
            // Expanded action bar
            if isExpanded {
                actionBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var cardBackground: some View {
        Group {
            if isSelected {
                Color.purple.opacity(0.08)
            } else if isHovering {
                Color(NSColor.selectedControlColor).opacity(0.3)
            } else {
                Color(NSColor.controlBackgroundColor)
            }
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return .purple.opacity(0.5)
        }
        return isHovering ? Color.secondary.opacity(0.2) : Color.clear
    }
    
    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                onAccept()
            } label: {
                Label("Use This", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.purple)
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
            
            // Copy button
            Button {
                copyToClipboard(response.text)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Copy to clipboard")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 4)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let confidence: Double
    
    private var color: Color {
        switch confidence {
        case 0.9...: return .green
        case 0.7..<0.9: return .yellow
        default: return .orange
        }
    }
    
    private var label: String {
        switch confidence {
        case 0.9...: return "High"
        case 0.7..<0.9: return "Good"
        default: return "Fair"
        }
    }
    
    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .cornerRadius(4)
    }
}

// MARK: - Suggestions List View (used in SuggestionPanel)

struct SuggestionsListView: View {
    let responses: [GeneratedResponse]
    @Binding var selectedVariant: UUID?
    @Binding var isExpanded: Bool
    
    let onAccept: (GeneratedResponse) -> Void
    let onEdit: (GeneratedResponse) -> Void
    let onRegenerate: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with count
            HStack {
                Text("\(responses.count) suggestions generated")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Variant cards
            ScrollView {
                VariantCards(
                    responses: responses,
                    selectedVariant: $selectedVariant,
                    isExpanded: $isExpanded,
                    onSelect: { _ in },
                    onAccept: onAccept,
                    onEdit: onEdit
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 300)
            
            Divider()
            
            // Footer actions
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                
                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - Preview

struct VariantCards_Previews: PreviewProvider {
    static var sampleResponses: [GeneratedResponse] = [
        GeneratedResponse(
            text: "Thank you for your email. I'll review this and get back to you by Friday.",
            tone: .professional,
            length: .brief,
            confidence: 0.95
        ),
        GeneratedResponse(
            text: "Thanks for reaching out! This sounds great. Let me take a closer look and I'll follow up soon.",
            tone: .friendly,
            length: .brief,
            confidence: 0.88
        ),
        GeneratedResponse(
            text: "I appreciate you sending this over. After a quick review, everything looks good. I'll need to confirm a couple of details with the team, but I expect we'll be able to move forward shortly.",
            tone: .formal,
            length: .standard,
            confidence: 0.82
        )
    ]
    
    static var previews: some View {
        VariantCards(
            responses: sampleResponses,
            selectedVariant: .constant(nil),
            isExpanded: .constant(false),
            onSelect: { _ in },
            onAccept: { _ in },
            onEdit: { _ in }
        )
        .padding()
        .frame(width: 400)
    }
}
