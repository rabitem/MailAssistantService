//
//  ToolbarInjector.swift
//  MailExtension
//

import Cocoa
import SwiftUI
import MailKit

/// Injects toolbar items into the Mail compose window
class ToolbarInjector: NSObject {
    
    // MARK: - Properties
    
    private var toolbarItems: [String: NSToolbarItem] = [:]
    private var quickActionsToolbar: QuickActionsToolbar?
    private var viewModel: QuickActionsViewModel
    private var composeSession: MEComposeSession?
    
    // MARK: - Toolbar Item Identifiers
    
    private enum ToolbarItemIdentifier {
        static let quickActions = "com.rabitem.KimiMailAssistant.quickActions"
        static let generate = "com.rabitem.KimiMailAssistant.generate"
        static let toneSelector = "com.rabitem.KimiMailAssistant.toneSelector"
        static let separator = "com.rabitem.KimiMailAssistant.separator"
    }
    
    // MARK: - Initialization
    
    init(viewModel: QuickActionsViewModel) {
        self.viewModel = viewModel
        super.init()
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Injects toolbar items into the compose window
    func inject(into window: NSWindow, for session: MEComposeSession) {
        self.composeSession = session
        viewModel.composeSession = session
        
        guard let toolbar = window.toolbar else {
            print("[ToolbarInjector] Window has no toolbar")
            return
        }
        
        // Ensure we have a delegate that can handle our items
        setupToolbarDelegate(toolbar)
        
        // Create and add toolbar items
        let quickActionsItem = createQuickActionsItem()
        let generateItem = createGenerateItem()
        
        // Store references
        toolbarItems[ToolbarItemIdentifier.quickActions] = quickActionsItem
        toolbarItems[ToolbarItemIdentifier.generate] = generateItem
        
        // Insert items into toolbar
        insertToolbarItem(quickActionsItem, into: toolbar, at: 0)
        insertToolbarItem(generateItem, into: toolbar, at: 1)
        
        print("[ToolbarInjector] Successfully injected toolbar items")
    }
    
    /// Removes toolbar items from the window
    func remove(from window: NSWindow) {
        guard let toolbar = window.toolbar else { return }
        
        for (_, item) in toolbarItems {
            toolbar.removeItem(at: toolbar.items.firstIndex(of: item) ?? 0)
        }
        
        toolbarItems.removeAll()
        quickActionsToolbar = nil
    }
    
    /// Updates the toolbar state
    func updateState(for session: MEComposeSession) {
        // Update any dynamic toolbar item states
    }
    
    // MARK: - Private Methods
    
    private func setupToolbarDelegate(_ toolbar: NSToolbar) {
        // The toolbar delegate needs to support our custom identifiers
        // If there's an existing delegate, we may need to wrap it
        
        if toolbar.delegate == nil {
            toolbar.delegate = self
        }
    }
    
    private func createQuickActionsItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .init(ToolbarItemIdentifier.quickActions))
        item.label = "Kimi"
        item.paletteLabel = "Kimi Mail Assistant"
        item.toolTip = "Quick actions for AI-powered writing assistance"
        
        // Create the SwiftUI view
        let quickActionsView = QuickActionsBar(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: quickActionsView)
        hostingView.frame.size = NSSize(width: 400, height: 40)
        
        item.view = hostingView
        item.minSize = NSSize(width: 300, height: 40)
        item.maxSize = NSSize(width: 600, height: 40)
        
        return item
    }
    
    private func createGenerateItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .init(ToolbarItemIdentifier.generate))
        item.label = "Generate"
        item.paletteLabel = "Generate Suggestions"
        item.toolTip = "Generate AI-powered response suggestions (⌘⇧G)"
        
        let button = NSButton()
        button.title = "Generate"
        button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = #selector(generateButtonTapped(_:))
        
        item.view = button
        item.target = self
        item.action = #selector(generateButtonTapped(_:))
        
        return item
    }
    
    private func createSeparatorItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .init(ToolbarItemIdentifier.separator))
        item.isBordered = false
        
        let separator = NSBox()
        separator.boxType = .separator
        
        item.view = separator
        item.minSize = NSSize(width: 1, height: 22)
        item.maxSize = NSSize(width: 1, height: 22)
        
        return item
    }
    
    private func insertToolbarItem(_ item: NSToolbarItem, into toolbar: NSToolbar, at index: Int) {
        // Add the item identifier to allowed items if using a custom delegate
        if let delegate = toolbar.delegate as? ToolbarInjector {
            delegate.allowedItemIdentifiers.append(item.itemIdentifier)
        }
        
        // Insert the item
        let safeIndex = min(index, toolbar.items.count)
        toolbar.insertItem(withItemIdentifier: item.itemIdentifier, at: safeIndex)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToolbarAction(_:)),
            name: .toolbarActionTriggered,
            object: nil
        )
    }
    
    @objc private func generateButtonTapped(_ sender: Any) {
        viewModel.generateSuggestions()
    }
    
    @objc private func handleToolbarAction(_ notification: Notification) {
        guard let action = notification.userInfo?["action"] as? String else { return }
        
        switch action {
        case "generate":
            viewModel.generateSuggestions()
        case "settings":
            viewModel.openSettings()
        default:
            break
        }
    }
}

// MARK: - NSToolbarDelegate

extension ToolbarInjector: NSToolbarDelegate {
    
    var allowedItemIdentifiers: [NSToolbarItem.Identifier] {
        get {
            return [
                .init(ToolbarItemIdentifier.quickActions),
                .init(ToolbarItemIdentifier.generate),
                .init(ToolbarItemIdentifier.toneSelector),
                .init(ToolbarItemIdentifier.separator)
            ]
        }
        set { /* no-op for compatibility */ }
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        return toolbarItems[itemIdentifier.rawValue]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .init(ToolbarItemIdentifier.quickActions),
            .init(ToolbarItemIdentifier.generate)
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return allowedItemIdentifiers
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }
}

// MARK: - Keyboard Shortcuts

/// Manages keyboard shortcuts for the extension
class KeyboardShortcutManager {
    
    static let shared = KeyboardShortcutManager()
    
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    private init() {}
    
    /// Registers keyboard shortcuts
    func registerShortcuts() {
        // Local monitor for when the app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event) ?? event
        }
        
        // Global monitor for system-wide shortcuts
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }
    
    /// Unregisters keyboard shortcuts
    func unregisterShortcuts() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard event.type == .keyDown else { return event }
        
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Check for specific shortcuts
        if modifierFlags == [.command, .shift] {
            switch event.keyCode {
            case 0x05: // G key
                // Generate suggestions
                NotificationCenter.default.post(name: .keyboardShortcutGenerate, object: nil)
                return nil // Consume the event
                
            case 0x01: // S key
                // Summarize
                NotificationCenter.default.post(name: .keyboardShortcutSummarize, object: nil)
                return nil
                
            case 0x0F: // R key
                // Regenerate
                NotificationCenter.default.post(name: .keyboardShortcutRegenerate, object: nil)
                return nil
                
            default:
                break
            }
        }
        
        return event
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let toolbarActionTriggered = Notification.Name("com.rabitem.KimiMailAssistant.toolbarActionTriggered")
    static let keyboardShortcutGenerate = Notification.Name("com.rabitem.KimiMailAssistant.keyboardShortcutGenerate")
    static let keyboardShortcutSummarize = Notification.Name("com.rabitem.KimiMailAssistant.keyboardShortcutSummarize")
    static let keyboardShortcutRegenerate = Notification.Name("com.rabitem.KimiMailAssistant.keyboardShortcutRegenerate")
}

// MARK: - Touch Bar Support

@available(macOS 10.12.2, *)
class ComposeTouchBar: NSTouchBar {
    
    private let viewModel: QuickActionsViewModel
    
    init(viewModel: QuickActionsViewModel) {
        self.viewModel = viewModel
        super.init()
        setupTouchBar()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTouchBar() {
        defaultItemIdentifiers = [
            .generate,
            .fixedSpaceSmall,
            .tone,
            .fixedSpaceSmall,
            .length,
            .flexibleSpace,
            .settings
        ]
        
        delegate = self
    }
}

@available(macOS 10.12.2, *)
extension ComposeTouchBar: NSTouchBarDelegate {
    
    enum TouchBarIdentifier {
        static let generate = NSTouchBarItem.Identifier("com.rabitem.KimiMailAssistant.touchbar.generate")
        static let tone = NSTouchBarItem.Identifier("com.rabitem.KimiMailAssistant.touchbar.tone")
        static let length = NSTouchBarItem.Identifier("com.rabitem.KimiMailAssistant.touchbar.length")
        static let settings = NSTouchBarItem.Identifier("com.rabitem.KimiMailAssistant.touchbar.settings")
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case TouchBarIdentifier.generate:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)!,
                                target: self,
                                action: #selector(generateTapped))
            item.customizationLabel = "Generate"
            return item
            
        case TouchBarIdentifier.tone:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let segmentedControl = NSSegmentedControl(labels: ["Formal", "Casual", "Friendly"],
                                                      trackingMode: .selectOne,
                                                      target: self,
                                                      action: #selector(toneChanged(_:)))
            segmentedControl.selectedSegment = 0
            item.view = segmentedControl
            item.customizationLabel = "Tone"
            return item
            
        case TouchBarIdentifier.length:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let segmentedControl = NSSegmentedControl(labels: ["Brief", "Standard", "Detailed"],
                                                      trackingMode: .selectOne,
                                                      target: self,
                                                      action: #selector(lengthChanged(_:)))
            segmentedControl.selectedSegment = 1
            item.view = segmentedControl
            item.customizationLabel = "Length"
            return item
            
        case TouchBarIdentifier.settings:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(image: NSImage(systemSymbolName: "gear", accessibilityDescription: nil)!,
                                target: self,
                                action: #selector(settingsTapped))
            item.customizationLabel = "Settings"
            return item
            
        default:
            return nil
        }
    }
    
    @objc private func generateTapped() {
        viewModel.generateSuggestions()
    }
    
    @objc private func toneChanged(_ sender: NSSegmentedControl) {
        let tones: [ResponseTone] = [.formal, .casual, .friendly]
        viewModel.selectedTone = tones[sender.selectedSegment]
    }
    
    @objc private func lengthChanged(_ sender: NSSegmentedControl) {
        let lengths: [ResponseLength] = [.brief, .standard, .detailed]
        viewModel.selectedLength = lengths[sender.selectedSegment]
    }
    
    @objc private func settingsTapped() {
        viewModel.openSettings()
    }
}

// MARK: - Menu Items

/// Adds menu items to Mail's menu bar
class MenuInjector {
    
    static let shared = MenuInjector()
    
    private var kimiMenu: NSMenu?
    private var originalHelpMenu: NSMenu?
    
    func injectMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        
        // Create Kimi menu
        let menu = NSMenu(title: "Kimi")
        
        // Add menu items
        menu.addItem(withTitle: "Generate Suggestions",
                    action: #selector(generateSuggestions),
                    keyEquivalent: "G")
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        
        menu.addItem(withTitle: "Check Grammar & Tone",
                    action: #selector(checkGrammar),
                    keyEquivalent: "T")
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "Summarize Thread",
                    action: #selector(summarizeThread),
                    keyEquivalent: "S")
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        
        menu.addItem(withTitle: "Improve Writing",
                    action: #selector(improveWriting),
                    keyEquivalent: "I")
        menu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "Settings...",
                    action: #selector(openSettings),
                    keyEquivalent: ",")
        menu.items.last?.keyEquivalentModifierMask = [.command]
        
        // Create menu item
        let menuItem = NSMenuItem(title: "Kimi", action: nil, keyEquivalent: "")
        menuItem.submenu = menu
        
        // Insert before Help menu
        let insertIndex = max(0, mainMenu.numberOfItems - 1)
        mainMenu.insertItem(menuItem, at: insertIndex)
        
        self.kimiMenu = menu
    }
    
    func removeMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        
        for (index, item) in mainMenu.items.enumerated() {
            if item.title == "Kimi" {
                mainMenu.removeItem(at: index)
                break
            }
        }
        
        kimiMenu = nil
    }
    
    @objc private func generateSuggestions() {
        NotificationCenter.default.post(name: .keyboardShortcutGenerate, object: nil)
    }
    
    @objc private func checkGrammar() {
        NotificationCenter.default.post(name: .showToneAnalysis, object: nil)
    }
    
    @objc private func summarizeThread() {
        NotificationCenter.default.post(name: .keyboardShortcutSummarize, object: nil)
    }
    
    @objc private func improveWriting() {
        NotificationCenter.default.post(name: .showImprovements, object: nil)
    }
    
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }
}
