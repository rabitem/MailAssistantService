import Foundation

/// Unique identifier for a plugin
public struct PluginID: Codable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ id: String) {
        self.rawValue = id
    }
}

extension PluginID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension PluginID: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}
