//
//  main.swift
//  MailAssistantService
//
//  XPC Service entry point - Background daemon for Mail Assistant
//

import Foundation
import os.log

// MARK: - Service Entry Point

let logger = Logger(subsystem: "com.kimimail.assistant.service", category: "Main")

// Create the service delegate
let delegate = ServiceDelegate()

// Set up the XPC listener
let listener = NSXPCListener.service()
listener.delegate = delegate

logger.info("📬 MailAssistantService starting...")

// Resume the listener and start the run loop
listener.resume()

// Keep the service running
RunLoop.main.run()
