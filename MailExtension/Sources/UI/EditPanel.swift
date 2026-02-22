//
//  EditPanel.swift
//  MailExtension
//

import SwiftUI

/// Panel for editing generated responses before inserting
struct EditPanel: View {
    @Binding var text: String
    let originalResponse: GeneratedResponse
    let onAccept: () -> Void
    let onCancel: () -> Void
    let onRegenerate: () -> Void
    
    @State private var selectedTone: ResponseTone
    @State private var selectedLength: ResponseLength
    @FocusState private var isEditorFocused: Bool
    
    init(text: Binding<String>, 
         originalResponse: GeneratedResponse,
         onAccept: @escaping () -> Void,
         onCancel: @escaping () -> Void,
         onRegenerate: @escaping () -> Void) {
        self._text = text
        self.originalResponse = originalResponse
        self.onAccept = onAccept
        self.onCancel = onCancel
        self.onRegenerate = onRegenerate
        self._selectedTone = State(initialValue: originalResponse.tone)
        self._selectedLength = State(initialValue: originalResponse.length)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Toolbar
            toolbar
            
            Divider()
            
            // Editor
            editor
            
            Divider()
            
            // Footer
            footer
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .frame(minWidth: 500, minHeight: 400)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .foregroundStyle(.purple)
                Text("Edit Response")
                    .font(.system(size: 13, weight: .semibold))
            }
            
            Spacer()
            
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // Tone selector
            Picker("Tone", selection: $selectedTone) {
                ForEach(ResponseTone.allCases) { tone in
                    Text(tone.displayName)
                        .tag(tone)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: selectedTone) { _ in
                // Could trigger regeneration with new tone
            }
            
            Spacer()
            
            // Action buttons
            Button {
                formatText(.bold)
            } label: {
                Image(systemName: "bold")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            
            Button {
                formatText(.italic)
            } label: {
                Image(systemName: "italic")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            
            Button {
                formatText(.bulletList)
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Editor
    
    private var editor: some View {
        TextEditor(text: $text)
            .font(.system(size: 13))
            .lineSpacing(4)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .focused($isEditorFocused)
            .onAppear {
                isEditorFocused = true
            }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "text.word.count")
                    .font(.system(size: 10))
                Text("\(wordCount) words")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    onAccept()
                } label: {
                    Label("Insert", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.purple)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private var wordCount: Int {
        text.split(separator: /\s+/).count
    }
    
    private enum FormatAction {
        case bold
        case italic
        case bulletList
        case numberedList
    }
    
    private func formatText(_ action: FormatAction) {
        // In a real implementation, this would apply formatting
        // For now, just a placeholder
    }
}

// MARK: - Edit Panel Window Controller

class EditPanelWindowController: NSWindowController {
    private var response: GeneratedResponse
    private var onAccept: (String) -> Void
    private var textBinding: Binding<String>
    
    init(response: GeneratedResponse, onAccept: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.response = response
        self.onAccept = onAccept
        
        var editedText = response.text
        self.textBinding = Binding(
            get: { editedText },
            set: { editedText = $0 }
        )
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Edit Response"
        panel.isFloatingPanel = true
        
        super.init(window: panel)
        
        let editPanel = EditPanel(
            text: textBinding,
            originalResponse: response,
            onAccept: { [weak self] in
                self?.close()
                onAccept(editedText)
            },
            onCancel: { [weak self] in
                self?.close()
                onCancel()
            },
            onRegenerate: { [weak self] in
                self?.handleRegenerate()
            }
        )
        
        let hostingView = NSHostingView(rootView: editPanel)
        panel.contentView = hostingView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func handleRegenerate() {
        // Trigger regeneration with current tone/length settings
        NotificationCenter.default.post(
            name: .keyboardShortcutRegenerate,
            object: nil
        )
    }
}

// MARK: - Preview

struct EditPanel_Previews: PreviewProvider {
    static var previews: some View {
        EditPanel(
            text: .constant("Thank you for your email. I'll review this and get back to you by Friday."),
            originalResponse: GeneratedResponse(
                text: "Thank you for your email. I'll review this and get back to you by Friday.",
                tone: .professional,
                length: .brief,
                confidence: 0.95
            ),
            onAccept: {},
            onCancel: {},
            onRegenerate: {}
        )
        .padding()
        .frame(width: 500, height: 400)
    }
}
