# Architecture Documentation

## Overview

Kimi Mail Assistant uses a multi-process architecture to ensure security, stability, and proper integration with macOS Mail.

## Process Model

### Main App (MailAssistant)
- User interface (SwiftUI)
- Settings management
- Plugin discovery and lifecycle
- XPC client to service

### Mail Extension (MailExtension.appex)
- Runs within Mail process
- Limited to MailKit APIs
- Communicates via XPC to service
- No direct network access (delegates to service)

### XPC Service (MailAssistantService)
- Background daemon
- Long-running process
- Manages AI provider connections
- Executes plugins
- Handles network requests

### PluginAPI (Framework)
- Shared library
- Used by all targets
- Defines plugin contracts

## Communication Flow

```
┌──────────────┐     XPC      ┌──────────────┐
│   Mail App   │◄────────────►│   MailExt    │
└──────────────┘              └──────┬───────┘
                                     │ XPC
                                     ▼
                            ┌──────────────┐
                            │    Service   │
                            └──────┬───────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
              ┌─────────┐   ┌──────────┐  ┌──────────┐
              │ Plugins │   │ AI APIs  │  │ Keychain │
              └─────────┘   └──────────┘  └──────────┘
```

## Security Model

### Sandboxing
- All targets use App Sandbox
- Minimal entitlements
- Network access only in service

### Data Isolation
- API keys stored in Keychain
- No email content persisted
- In-memory processing only

### XPC Security
- Protocol-based interfaces
- Type-safe message passing
- Connection validation

## Plugin System

### Loading
1. Scan plugin directories
2. Validate manifest
3. Load into isolated context
4. Initialize plugin

### Execution
- Plugins run in service process
- Timeout for long operations
- Error handling and recovery

### API
See `PluginAPI/Sources/PluginAPI.swift`

## AI Provider Architecture

### Provider Protocol
```swift
protocol AIProviderProtocol {
    func generateSuggestions(...) async throws -> [Suggestion]
}
```

### Built-in Providers
- Kimi (Moonshot AI)
- OpenAI (GPT)
- Anthropic (Claude)
- Local (ONNX/CoreML)

### Provider Selection
- User preference in settings
- Fallback chain
- Provider-specific configuration

## Data Flow

### Compose-time Suggestions
1. User types in Mail compose window
2. Extension captures text changes
3. XPC call to service
4. Service queries AI provider
5. Results returned to extension
6. Extension displays suggestions

### Message Actions
1. User triggers action on message
2. Extension captures action
3. XPC call to service with message
4. Service processes via plugin
5. Result returned to Mail

## Error Handling

### XPC Errors
- Connection retry with backoff
- Graceful degradation
- User notification

### AI Provider Errors
- Rate limiting
- Authentication failures
- Network timeouts

### Plugin Errors
- Sandboxing violations
- Timeout handling
- Crash recovery

## Performance

### Caching
- Suggestion caching
- Plugin result memoization
- Configuration caching

### Optimization
- Lazy loading of plugins
- Connection pooling
- Request batching

## Future Enhancements

### Planned
- CoreML local models
- Plugin marketplace
- Advanced analytics
- Team/corporate features

### Considerations
- iOS support (MailKit on iOS)
- Cloud sync
- Collaborative features
