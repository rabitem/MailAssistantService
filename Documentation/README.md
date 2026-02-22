# Kimi Mail Assistant

An AI-powered macOS Mail extension that provides intelligent email assistance using a plugin architecture.

## Project Structure

### Targets

1. **KimiMailAssistant** (Main App) - macOS application
   - SwiftUI-based interface
   - Plugin management
   - AI provider configuration
   - Usage statistics dashboard

2. **MailExtension** (Mail App Extension) - .appex
   - Integrates with macOS Mail app
   - Provides compose-time suggestions
   - Message decorations and actions
   - Real-time writing assistance

3. **MailAssistantService** (XPC Service) - Background daemon
   - Handles AI provider communication
   - Plugin execution
   - Secure credential storage
   - Runs independently of main app

4. **PluginAPI** (Swift Module)
   - Public SDK for plugin development
   - Shared protocols and data types
   - Plugin registry

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      macOS Mail App                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ MailKit Extension Point
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  MailExtension (.appex)                      │
│  - MessageViewController                                     │
│  - ComposeSessionHandler                                     │
│  - ActionHandler                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ XPC
                         ▼
┌─────────────────────────────────────────────────────────────┐
│               MailAssistantService (XPC)                     │
│  - AI Provider Management                                    │
│  - Plugin Execution                                          │
│  - Secure API Key Storage                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Plugin API
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      Plugins                                 │
│  - Core Plugins                                              │
│  - AI Provider Plugins                                       │
│  - Optional Community Plugins                                │
└─────────────────────────────────────────────────────────────┘
```

## Building

### Requirements
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Build Steps

```bash
# Open the project
open KimiMailAssistant.xcodeproj

# Or build from command line
xcodebuild -project KimiMailAssistant.xcodeproj -scheme KimiMailAssistant build
```

## Configuration

### API Keys
Store API keys in macOS Keychain:
- Open Keychain Access
- Add a new password item
- Service name: `com.rabitem.KimiMailAssistant.apikeys`

### Enabling the Extension
1. Build and run the main app
2. Open Mail → Settings → Extensions
3. Enable "Kimi Mail Assistant"

## Plugin Development

See `PluginAPI/Sources/PluginAPI.swift` for the full API documentation.

### Example Plugin

```swift
import PluginAPI

public class MyPlugin: EmailProcessingPlugin {
    public static let pluginIdentifier = "com.example.myplugin"
    public static let pluginName = "My Plugin"
    public static let pluginVersion = "1.0.0"
    public static let pluginDescription = "Does something cool"
    public static let pluginAuthor = "Your Name"
    
    required public init() {}
    
    public func pluginDidLoad() {
        // Setup
    }
    
    public func pluginWillUnload() {
        // Cleanup
    }
    
    public var supportedTypes: [ProcessingType] {
        [.summarize, .classify]
    }
    
    public func process(_ email: EmailContent) async throws -> ProcessResult {
        // Process the email
        return .success("Processed!")
    }
}
```

## License

MIT License - See LICENSE file for details
