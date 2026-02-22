import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - UI Plugin

/// Protocol for plugins that provide custom UI components or panels
public protocol UIPlugin: Plugin {
    /// The panels provided by this plugin
    var panels: [UIPanel] { get }
    
    /// Toolbar items to add to the main interface
    var toolbarItems: [UIToolbarItem] { get }
    
    /// Context menu items for emails
    var contextMenuItems: [UIContextMenuItem] { get }
    
    /// Settings view for the plugin
    func settingsView() -> AnyView?
    
    /// Get a specific panel by ID
    func panel(id: String) -> UIPanel?
    
    /// Handle a deep link from the plugin
    func handleDeepLink(_ url: URL) async -> Bool
}

// MARK: - UI Panel

/// Represents a custom UI panel provided by a plugin
public struct UIPanel: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let iconName: String
    public let position: PanelPosition
    public let defaultSize: PanelSize
    public let minimumSize: PanelSize?
    public let maximumSize: PanelSize?
    public let resizable: Bool
    public let closable: Bool
    public let contentProvider: @Sendable () -> AnyView
    
    public init(
        id: String,
        title: String,
        iconName: String,
        position: PanelPosition = .sidebar,
        defaultSize: PanelSize = PanelSize(width: 300, height: 400),
        minimumSize: PanelSize? = nil,
        maximumSize: PanelSize? = nil,
        resizable: Bool = true,
        closable: Bool = true,
        contentProvider: @escaping @Sendable () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.position = position
        self.defaultSize = defaultSize
        self.minimumSize = minimumSize
        self.maximumSize = maximumSize
        self.resizable = resizable
        self.closable = closable
        self.contentProvider = contentProvider
    }
}

// MARK: - Panel Position

public enum PanelPosition: String, Codable, Sendable {
    case sidebar // Left or right sidebar
    case bottomBar // Bottom panel
    case floating // Floating window
    case modal // Modal dialog
    case inline // Inline within email view
    case overlay // Overlay on top of content
}

// MARK: - Panel Size

public struct PanelSize: Codable, Sendable {
    public let width: Double
    public let height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    
    public static let small = PanelSize(width: 200, height: 300)
    public static let medium = PanelSize(width: 400, height: 500)
    public static let large = PanelSize(width: 600, height: 700)
}

// MARK: - UI Toolbar Item

public struct UIToolbarItem: Identifiable, Sendable {
    public let id: String
    public let iconName: String
    public let title: String
    public let shortcut: String?
    public let placement: ToolbarPlacement
    public let action: @Sendable () async -> Void
    
    public init(
        id: String,
        iconName: String,
        title: String,
        shortcut: String? = nil,
        placement: ToolbarPlacement = .primary,
        action: @escaping @Sendable () async -> Void
    ) {
        self.id = id
        self.iconName = iconName
        self.title = title
        self.shortcut = shortcut
        self.placement = placement
        self.action = action
    }
}

// MARK: - Toolbar Placement

public enum ToolbarPlacement: String, Codable, Sendable {
    case primary // Main toolbar
    case secondary // Secondary toolbar
    case compose // Compose window toolbar
    case emailView // Email reading view
    case threadView // Thread view
}

// MARK: - UI Context Menu Item

public struct UIContextMenuItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let iconName: String?
    public let shortcut: String?
    public let section: ContextMenuSection
    public let predicate: @Sendable (Email) -> Bool
    public let action: @Sendable (Email) async -> Void
    
    public init(
        id: String,
        title: String,
        iconName: String? = nil,
        shortcut: String? = nil,
        section: ContextMenuSection = .actions,
        predicate: @escaping @Sendable (Email) -> Bool = { _ in true },
        action: @escaping @Sendable (Email) async -> Void
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.shortcut = shortcut
        self.section = section
        self.predicate = predicate
        self.action = action
    }
}

// MARK: - Context Menu Section

public enum ContextMenuSection: String, Codable, Sendable {
    case info = "info"
    case actions = "actions"
    case organization = "organization"
    case integrations = "integrations"
    case automation = "automation"
    case share = "share"
}

// MARK: - UI Preferences

public struct UIPluginPreferences: Codable, Sendable {
    public var panelsEnabled: [String: Bool]
    public var panelPositions: [String: PanelPosition]
    public var panelSizes: [String: PanelSize]
    public var toolbarItemsVisible: [String: Bool]
    
    public init(
        panelsEnabled: [String: Bool] = [:],
        panelPositions: [String: PanelPosition] = [:],
        panelSizes: [String: PanelSize] = [:],
        toolbarItemsVisible: [String: Bool] = [:]
    ) {
        self.panelsEnabled = panelsEnabled
        self.panelPositions = panelPositions
        self.panelSizes = panelSizes
        self.toolbarItemsVisible = toolbarItemsVisible
    }
}

// MARK: - View Container

/// Protocol for hosting plugin-provided views
public protocol ViewContainer: AnyObject, Sendable {
    func addPanel(_ panel: UIPanel)
    func removePanel(id: String)
    func updatePanel(id: String, configuration: PanelConfiguration)
    func presentModal(_ view: AnyView, configuration: ModalConfiguration)
    func dismissModal()
}

// MARK: - Panel Configuration

public struct PanelConfiguration: Codable, Sendable {
    public var isVisible: Bool?
    public var position: PanelPosition?
    public var size: PanelSize?
    public var title: String?
    
    public init(
        isVisible: Bool? = nil,
        position: PanelPosition? = nil,
        size: PanelSize? = nil,
        title: String? = nil
    ) {
        self.isVisible = isVisible
        self.position = position
        self.size = size
        self.title = title
    }
}

// MARK: - Modal Configuration

public struct ModalConfiguration: Codable, Sendable {
    public let title: String?
    public let size: ModalSize
    public let dismissible: Bool
    public let animated: Bool
    
    public init(
        title: String? = nil,
        size: ModalSize = .medium,
        dismissible: Bool = true,
        animated: Bool = true
    ) {
        self.title = title
        self.size = size
        self.dismissible = dismissible
        self.animated = animated
    }
}

// MARK: - Modal Size

public enum ModalSize: String, Codable, Sendable {
    case small
    case medium
    case large
    case fullscreen
}

// MARK: - UI Event

/// Events related to UI interactions
public enum UIEvent: Sendable {
    case panelOpened(panelID: String)
    case panelClosed(panelID: String)
    case panelResized(panelID: String, size: PanelSize)
    case toolbarItemTapped(itemID: String)
    case contextMenuItemSelected(itemID: String, emailID: UUID)
    case settingsOpened
    case settingsClosed
    case deepLinkReceived(URL)
}

// MARK: - AnyView Placeholder

/// Type-erased view for plugin compatibility
/// Note: In a real implementation, this would wrap SwiftUI's AnyView
public struct AnyView: Sendable {
    private let _view: @Sendable () -> Any
    
    public init<V>(_ view: V) where V: View {
        self._view = { view }
    }
    
    public var body: Any {
        _view()
    }
}

// MARK: - View Protocol Placeholder

/// Placeholder for SwiftUI's View protocol
/// In a real implementation, this would use SwiftUI.View
public protocol View: Sendable {
    associatedtype Body: View
    @ViewBuilder var body: Self.Body { get }
}

// MARK: - ViewBuilder Placeholder

@resultBuilder
public struct ViewBuilder {
    public static func buildBlock<V: View>(_ view: V) -> V {
        view
    }
    
    public static func buildOptional<V: View>(_ view: V?) -> V? {
        view
    }
    
    public static func buildEither<True: View, False: View>(first view: True) -> _ConditionalContent<True, False> {
        _ConditionalContent(storage: .trueContent(view))
    }
    
    public static func buildEither<True: View, False: View>(second view: False) -> _ConditionalContent<True, False> {
        _ConditionalContent(storage: .falseContent(view))
    }
}

// MARK: - Conditional Content

public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View {
    public enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
    
    public let storage: Storage
    
    public var body: some Never {
        fatalError("This is a placeholder implementation")
    }
}

public enum Never: View {
    public var body: Never {
        fatalError()
    }
}

// MARK: - Empty View

public struct EmptyView: View {
    public init() {}
    
    public var body: some Never {
        fatalError()
    }
}

// MARK: - Text View

public struct Text: View {
    let content: String
    
    public init(_ content: String) {
        self.content = content
    }
    
    public var body: some Never {
        fatalError()
    }
}
