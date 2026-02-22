import Foundation
import os.log

// MARK: - Logger

public struct Logger {
    
    // MARK: - Properties
    
    private let osLog: OSLog
    
    // MARK: - Initialization
    
    public init(subsystem: String, category: String) {
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    // MARK: - Logging Methods
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log("[%{public}@:%{public}@:%{public}d] %{public}@", log: osLog, type: .debug, fileName, function, line, message)
        #endif
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log("[%{public}@:%{public}@:%{public}d] %{public}@", log: osLog, type: .info, fileName, function, line, message)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log("[%{public}@:%{public}@:%{public}d] %{public}@", log: osLog, type: .default, fileName, function, line, message)
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log("[%{public}@:%{public}@:%{public}d] %{public}@", log: osLog, type: .error, fileName, function, line, message)
    }
    
    public func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        os_log("[%{public}@:%{public}@:%{public}d] %{public}@", log: osLog, type: .fault, fileName, function, line, message)
    }
}
