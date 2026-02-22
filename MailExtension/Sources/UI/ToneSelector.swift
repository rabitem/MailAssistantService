//
//  ToneSelector.swift
//  MailExtension
//

import SwiftUI

/// Tone and style selection component
struct ToneSelector: View {
    @Binding var selectedTone: ResponseTone
    @Binding var selectedLength: ResponseLength
    @Binding var selectedProfile: StyleProfile
    
    let onChange: () -> Void
    
    @State private var showProfileSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tone Selection
            toneSection
            
            Divider()
            
            // Length Selection
            lengthSection
            
            Divider()
            
            // Style Profile
            profileSection
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Tone Section
    
    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Tone")
                    .font(.system(size: 11, weight: .semibold))
            } icon: {
                Image(systemName: "text.quote")
                    .foregroundStyle(.purple)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(ResponseTone.allCases) { tone in
                    ToneButton(
                        tone: tone,
                        isSelected: selectedTone == tone,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTone = tone
                                onChange()
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Length Section
    
    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Length")
                    .font(.system(size: 11, weight: .semibold))
            } icon: {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.purple)
            }
            
            Picker("", selection: $selectedLength) {
                ForEach(ResponseLength.allCases) { length in
                    Text(length.displayName)
                        .tag(length)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .onChange(of: selectedLength) { _ in
                onChange()
            }
            
            Text(selectedLength.description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text("Style Profile")
                        .font(.system(size: 11, weight: .semibold))
                } icon: {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(.purple)
                }
                
                Spacer()
                
                Button {
                    showProfileSheet = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
            
            Menu {
                ForEach(availableProfiles) { profile in
                    Button {
                        selectedProfile = profile
                        selectedTone = profile.tone
                        selectedLength = profile.length
                        onChange()
                    } label: {
                        HStack {
                            Text(profile.name)
                            if selectedProfile.id == profile.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button("Manage Profiles...") {
                    showProfileSheet = true
                }
            } label: {
                HStack {
                    Text(selectedProfile.name)
                        .font(.system(size: 12))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
        }
    }
    
    private var availableProfiles: [StyleProfile] {
        [
            .default,
            .quick,
            .formal,
            StyleProfile(name: "Customer Support", tone: .empathetic, length: .detailed),
            StyleProfile(name: "Executive", tone: .professional, length: .brief)
        ]
    }
}

// MARK: - Tone Button

struct ToneButton: View {
    let tone: ResponseTone
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tone.icon)
                    .font(.system(size: 14))
                Text(tone.displayName)
                    .font(.system(size: 10))
            }
            .frame(width: 64, height: 44)
            .background(isSelected ? Color.purple.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? .purple : .secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.purple.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(tone.description)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Style Profile Sheet

struct StyleProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Style Profiles")
                .font(.headline)
            
            Text("Create and manage custom writing style profiles for different contexts.")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            // Profile list would go here
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Preview

struct ToneSelector_Previews: PreviewProvider {
    static var previews: some View {
        ToneSelector(
            selectedTone: .constant(.professional),
            selectedLength: .constant(.standard),
            selectedProfile: .constant(.default),
            onChange: {}
        )
        .padding()
        .frame(width: 320)
    }
}
