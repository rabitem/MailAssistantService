//
//  Theme.swift
//  MailExtension
//

import SwiftUI

/// Theme definitions for consistent styling across the extension
enum KimiTheme {
    
    // MARK: - Colors
    
    enum Colors {
        static let primary = Color.purple
        static let primaryLight = Color.purple.opacity(0.15)
        static let primaryDark = Color.purple.opacity(0.7)
        
        static let success = Color.green
        static let warning = Color.yellow
        static let error = Color.red
        
        static let background = Color(NSColor.controlBackgroundColor)
        static let cardBackground = Color(NSColor.windowBackgroundColor)
        static let textBackground = Color(NSColor.textBackgroundColor)
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let title = Font.system(size: 16, weight: .semibold)
        static let headline = Font.system(size: 14, weight: .semibold)
        static let body = Font.system(size: 13)
        static let caption = Font.system(size: 11)
        static let small = Font.system(size: 10)
    }
    
    // MARK: - Layout
    
    enum Layout {
        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 12
        static let paddingLarge: CGFloat = 16
        
        static let cornerRadiusSmall: CGFloat = 6
        static let cornerRadiusMedium: CGFloat = 8
        static let cornerRadiusLarge: CGFloat = 12
        
        static let shadowRadiusSmall: CGFloat = 2
        static let shadowRadiusMedium: CGFloat = 4
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
    }
}

// MARK: - View Modifiers

extension View {
    func kimiCardStyle() -> some View {
        self
            .background(KimiTheme.Colors.cardBackground)
            .cornerRadius(KimiTheme.Layout.cornerRadiusMedium)
            .shadow(
                color: .black.opacity(0.05),
                radius: KimiTheme.Layout.shadowRadiusSmall,
                x: 0,
                y: 1
            )
    }
    
    func kimiButtonStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(KimiTheme.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(KimiTheme.Layout.cornerRadiusSmall)
    }
}

// MARK: - Extensions

extension NSColor {
    static let kimiPrimary = NSColor.purple
    static let kimiPrimaryLight = NSColor.purple.withAlphaComponent(0.15)
}

// MARK: - Accessibility

enum KimiAccessibility {
    static let suggestionPanelLabel = "Kimi AI Suggestions"
    static let generateButtonLabel = "Generate AI suggestions"
    static let acceptButtonLabel = "Accept suggestion"
    static let editButtonLabel = "Edit suggestion"
    static let regenerateButtonLabel = "Regenerate suggestions"
}
