//
//  MailImporter.swift
//  MailAssistantService
//
//  Import emails from Mail.app - handles permissions and incremental sync
//

import Foundation
import os.log
import CoreData

// MARK: - Mail Importer

/// Handles importing emails from the macOS Mail.app
class MailImporter {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.kimimail.assistant.service", category: "MailImporter")
    private let databaseQueue = DispatchQueue(label: "com.kimimail.importer", qos: .utility)
    
    /// Last import timestamp for incremental sync
    private var lastImportDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastEmailImportDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastEmailImportDate")
        }
    }
    
    /// Tracks import statistics
    private(set) var importStatistics = ImportStatistics()
    
    // MARK: - Permissions
    
    /// Checks if the service has permission to access Mail.app data
    func checkPermission() -> PermissionStatus {
        // Check Full Disk Access permission
        let fileManager = FileManager.default
        
        // Try to access the Mail data directory
        let mailDataPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail")
        
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: mailDataPath.path, isDirectory: &isDirectory)
        
        if !exists {
            logger.warning("Mail data directory not found")
            return .notAvailable
        }
        
        // Try to list contents to verify access
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: mailDataPath.path)
            logger.info("✅ Full Disk Access granted - found \(contents.count) items in Mail directory")
            return .granted
        } catch {
            logger.warning("❌ Full Disk Access not granted or error: \(error.localizedDescription)")
            return .denied
        }
    }
    
    /// Requests permission to access Mail.app data
    func requestPermission(completion: @escaping (PermissionStatus) -> Void) {
        let status = checkPermission()
        
        if status == .denied {
            logger.info("🔐 Requesting Full Disk Access permission...")
            
            // Open System Preferences to Security & Privacy
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
            NSWorkspace.shared.open(url)
        }
        
        completion(status)
    }
    
    // MARK: - Import Operations
    
    /// Imports new emails from Mail.app (incremental sync)
    func importNewEmails(completion: @escaping (Result<Int, ImportError>) -> Void) {
        databaseQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.serviceUnavailable))
                return
            }
            
            // Check permissions
            let permission = self.checkPermission()
            guard permission == .granted else {
                self.logger.error("❌ Cannot import: permission not granted (\(permission))")
                completion(.failure(.permissionDenied))
                return
            }
            
            self.logger.info("📧 Starting email import...")
            
            do {
                let count = try self.performImport()
                self.lastImportDate = Date()
                self.importStatistics.recordSuccessfulImport(count: count)
                
                self.logger.info("✅ Email import complete: \(count) emails imported")
                completion(.success(count))
                
            } catch let error as ImportError {
                self.importStatistics.recordFailedImport(error: error)
                self.logger.error("❌ Email import failed: \(error.localizedDescription)")
                completion(.failure(error))
            } catch {
                let importError = ImportError.unknown(error)
                self.importStatistics.recordFailedImport(error: importError)
                self.logger.error("❌ Email import failed with unknown error: \(error.localizedDescription)")
                completion(.failure(importError))
            }
        }
    }
    
    /// Performs a full re-import of all emails
    func performFullImport(completion: @escaping (Result<Int, ImportError>) -> Void) {
        databaseQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.serviceUnavailable))
                return
            }
            
            self.logger.info("🔄 Starting full email re-import...")
            
            // Reset last import date to force full import
            self.lastImportDate = nil
            
            do {
                let count = try self.performImport(full: true)
                self.lastImportDate = Date()
                self.importStatistics.recordSuccessfulImport(count: count)
                
                self.logger.info("✅ Full import complete: \(count) emails imported")
                completion(.success(count))
                
            } catch let error as ImportError {
                self.importStatistics.recordFailedImport(error: error)
                completion(.failure(error))
            } catch {
                completion(.failure(.unknown(error)))
            }
        }
    }
    
    // MARK: - Private Import Logic
    
    private func performImport(full: Bool = false) throws -> Int {
        var importedCount = 0
        
        // Get Mail data directories
        let mailDataPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail")
        
        // Find all mailboxes (V10 for macOS Sonoma+, V9 for Ventura, etc.)
        let mailVersions = ["V10", "V9", "V8", "V7", "V6"]
        
        for version in mailVersions {
            let versionPath = mailDataPath.appendingPathComponent(version)
            guard FileManager.default.fileExists(atPath: versionPath.path) else {
                continue
            }
            
            logger.debug("Found Mail version: \(version)")
            
            // Process each account/mailbox
            let accounts = try listMailAccounts(at: versionPath)
            
            for account in accounts {
                do {
                    let count = try importFromAccount(account, fullImport: full)
                    importedCount += count
                } catch {
                    logger.warning("Failed to import from account \(account.name): \(error)")
                }
            }
        }
        
        return importedCount
    }
    
    private func listMailAccounts(at path: URL) throws -> [MailAccount] {
        let contents = try FileManager.default.contentsOfDirectory(atPath: path.path)
        
        return contents.compactMap { item in
            let itemPath = path.appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            
            guard FileManager.default.fileExists(atPath: itemPath.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  !item.hasPrefix(".") else {
                return nil
            }
            
            return MailAccount(name: item, path: itemPath)
        }
    }
    
    private func importFromAccount(_ account: MailAccount, fullImport: Bool) throws -> Int {
        logger.debug("Importing from account: \(account.name)")
        
        var count = 0
        
        // Find all .mbox directories
        let mboxEnumerator = FileManager.default.enumerator(
            at: account.path,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = mboxEnumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "mbox" {
                do {
                    let imported = try importFromMailbox(fileURL, fullImport: fullImport)
                    count += imported
                } catch {
                    logger.warning("Failed to import from \(fileURL.lastPathComponent): \(error)")
                }
            }
        }
        
        return count
    }
    
    private func importFromMailbox(_ mboxURL: URL, fullImport: Bool) throws -> Int {
        // Look for .emlx files (individual emails)
        let emlxFiles = try FileManager.default.contentsOfDirectory(atPath: mboxURL.path)
            .filter { $0.hasSuffix(".emlx") }
        
        var importedCount = 0
        let cutoffDate = fullImport ? nil : lastImportDate
        
        for emlxFile in emlxFiles.prefix(1000) { // Limit batch size
            let fileURL = mboxURL.appendingPathComponent(emlxFile)
            
            // Check file modification date for incremental import
            if let cutoff = cutoffDate {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let modDate = attributes[.modificationDate] as? Date,
                   modDate < cutoff {
                    continue
                }
            }
            
            do {
                if try importEmail(from: fileURL) {
                    importedCount += 1
                }
            } catch {
                logger.debug("Failed to import email \(emlxFile): \(error)")
            }
            
            // Yield to prevent blocking
            if importedCount % 100 == 0 {
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
        
        return importedCount
    }
    
    private func importEmail(from fileURL: URL) throws -> Bool {
        // Read .emlx file
        let data = try Data(contentsOf: fileURL)
        
        // Parse the email
        guard let email = try parseEmlx(data: data, sourceURL: fileURL) else {
            return false
        }
        
        // Save to local database
        try saveEmail(email)
        
        return true
    }
    
    private func parseEmlx(data: Data, sourceURL: URL) throws -> ImportedEmail? {
        // .emlx format: first line is length, then RFC822 message, then plist
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let lines = content.components(separatedBy: .newlines)
        guard let firstLine = lines.first,
              let messageLength = Int(firstLine.trimmingCharacters(in: .whitespaces)),
              messageLength > 0 else {
            return nil
        }
        
        // Extract the RFC822 message
        let messageStart = content.index(content.startIndex, offsetBy: firstLine.count + 1)
        let messageEnd = content.index(messageStart, offsetBy: messageLength)
        
        guard messageEnd <= content.endIndex else {
            return nil
        }
        
        let rfc822Message = String(content[messageStart..<messageEnd])
        
        // Parse headers
        let headers = parseHeaders(from: rfc822Message)
        
        guard let messageID = headers["message-id"],
              let subject = headers["subject"],
              let from = headers["from"] else {
            return nil
        }
        
        // Parse date
        let date = parseDate(headers["date"]) ?? Date()
        
        // Extract body (after headers)
        let body = extractBody(from: rfc822Message)
        
        return ImportedEmail(
            id: messageID.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: decodeMIMEHeader(subject),
            sender: parseEmailAddress(from),
            recipients: parseRecipients(headers["to"]),
            cc: parseRecipients(headers["cc"]),
            date: date,
            body: body,
            sourcePath: sourceURL.path,
            threadID: nil // Will be set by ThreadTracker
        )
    }
    
    private func parseHeaders(from message: String) -> [String: String] {
        var headers: [String: String] = [:]
        let lines = message.components(separatedBy: .newlines)
        
        var currentKey: String?
        var currentValue = ""
        
        for line in lines {
            // Empty line indicates end of headers
            if line.isEmpty {
                if let key = currentKey {
                    headers[key.lowercased()] = currentValue.trimmingCharacters(in: .whitespaces)
                }
                break
            }
            
            // Continuation line (starts with whitespace)
            if let first = line.first, first.isWhitespace {
                currentValue += " " + line.trimmingCharacters(in: .whitespaces)
            } else if let colonIndex = line.firstIndex(of: ":") {
                // New header
                if let key = currentKey {
                    headers[key.lowercased()] = currentValue.trimmingCharacters(in: .whitespaces)
                }
                
                let key = String(line[..<colonIndex]).lowercased()
                let value = String(line[line.index(after: colonIndex)...])
                
                currentKey = key
                currentValue = value
            }
        }
        
        return headers
    }
    
    private func extractBody(from message: String) -> String {
        guard let emptyLineRange = message.range(of: "\n\n") else {
            return message
        }
        
        let bodyStart = message.index(emptyLineRange.upperBound, offsetBy: 0)
        return String(message[bodyStart...])
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatters = [
            "EEE, d MMM yyyy HH:mm:ss zzz",
            "d MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd HH:mm:ss Z"
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        for format in formatters {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString.trimmingCharacters(in: .whitespaces)) {
                return date
            }
        }
        
        return nil
    }
    
    private func parseEmailAddress(_ string: String) -> EmailAddress {
        // Simple parsing - would need more robust regex for production
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let match = trimmed.range(of: "<(.+)>", options: .regularExpression) {
            let name = String(trimmed[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
            let email = String(trimmed[match]).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            return EmailAddress(name: name.isEmpty ? nil : name, email: email)
        }
        
        return EmailAddress(name: nil, email: trimmed)
    }
    
    private func parseRecipients(_ string: String?) -> [EmailAddress] {
        guard let string = string else { return [] }
        
        return string.components(separatedBy: ",")
            .map { parseEmailAddress($0) }
    }
    
    private func decodeMIMEHeader(_ string: String) -> String {
        // Simple MIME decoding - =?charset?encoding?data?=
        var result = string
        
        // Handle basic quoted-printable
        if result.hasPrefix("=?") && result.hasSuffix("?=") {
            // This is a simplified version - real implementation would need full MIME decoding
            result = result.replacingOccurrences(of: "=?UTF-8?Q?", with: "")
            result = result.replacingOccurrences(of: "=?utf-8?Q?", with: "")
            result = result.replacingOccurrences(of: "?=", with: "")
            result = result.replacingOccurrences(of: "_", with: " ")
            // Decode =XX hex sequences
            result = result.replacingOccurrences(
                of: "=[0-9A-F]{2}",
                with: { match in
                    let hex = String(match.dropFirst())
                    if let byte = UInt8(hex, radix: 16) {
                        return String(UnicodeScalar(byte))
                    }
                    return match
                },
                options: .regularExpression
            )
        }
        
        return result
    }
    
    private func saveEmail(_ email: ImportedEmail) throws {
        // TODO: Save to CoreData or SQLite database
        // This is a placeholder - actual implementation would use the DatabaseManager
        logger.debug("Saving email: \(email.id)")
    }
}

// MARK: - Supporting Types

enum PermissionStatus {
    case granted
    case denied
    case notAvailable
    case unknown
}

enum ImportError: Error, LocalizedError {
    case permissionDenied
    case serviceUnavailable
    case databaseError
    case parseError
    case accountAccessFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Full Disk Access permission is required to import emails"
        case .serviceUnavailable:
            return "The import service is unavailable"
        case .databaseError:
            return "A database error occurred while importing"
        case .parseError:
            return "Failed to parse email data"
        case .accountAccessFailed:
            return "Failed to access mail account"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

struct ImportStatistics {
    private(set) var totalImported: Int = 0
    private(set) var totalFailed: Int = 0
    private(set) var lastImportTime: Date?
    private(set) var lastError: ImportError?
    private(set) var importHistory: [ImportRecord] = []
    
    mutating func recordSuccessfulImport(count: Int) {
        totalImported += count
        lastImportTime = Date()
        importHistory.append(ImportRecord(timestamp: Date(), count: count, success: true))
        trimHistory()
    }
    
    mutating func recordFailedImport(error: ImportError) {
        totalFailed += 1
        lastError = error
        importHistory.append(ImportRecord(timestamp: Date(), count: 0, success: false, error: error))
        trimHistory()
    }
    
    private mutating func trimHistory() {
        // Keep only last 100 records
        if importHistory.count > 100 {
            importHistory.removeFirst(importHistory.count - 100)
        }
    }
}

struct ImportRecord {
    let timestamp: Date
    let count: Int
    let success: Bool
    let error: ImportError?
}

struct MailAccount {
    let name: String
    let path: URL
}

struct EmailAddress: Codable {
    let name: String?
    let email: String
    
    var displayString: String {
        if let name = name, !name.isEmpty {
            return "\(name) <\(email)>"
        }
        return email
    }
}

struct ImportedEmail: Codable {
    let id: String
    let subject: String
    let sender: EmailAddress
    let recipients: [EmailAddress]
    let cc: [EmailAddress]
    let date: Date
    let body: String
    let sourcePath: String
    var threadID: String?
}
