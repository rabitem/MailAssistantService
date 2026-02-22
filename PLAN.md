# MailAssistant — Full-Scoped Architecture Plan

> A plugin-powered macOS Mail extension with AI-driven response suggestions, built for extensibility, privacy, and scale.

---

## 🎯 Vision

Transform macOS Mail into an intelligent communication hub where **everything is a plugin**. Core features ship as plugins. Third-party developers can extend. Users customize their experience.

---

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           macOS Mail App                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Mail App Extension (.appex)                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │
│  │  │  Compose    │  │ Suggestion  │  │   Toolbar   │                 │   │
│  │  │  Injector   │  │   Panel     │  │   Buttons   │                 │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │ XPC (NSXPCConnection)
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 MailAssistantService (Background Daemon)                     │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        Plugin Engine                                   │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │  │
│  │  │  PluginManager  │  │   EventBus      │  │  Sandbox        │       │  │
│  │  │  (lifecycle)    │  │   (pub/sub)     │  │  (security)     │       │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      Active Plugins                                    │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────────────┐  │  │
│  │  │ StyleLearner │ │ ResponseGen  │ │  FollowUp    │ │  SmartArch  │  │  │
│  │  │   (Core)     │ │   (Core)     │ │  (Optional)  │ │  (Optional) │  │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └─────────────┘  │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────────────┐  │  │
│  │  │   Kimi AI    │ │  OpenAI      │ │  Anthropic   │ │   Ollama    │  │  │
│  │  │  (Provider)  │ │  (Provider)  │ │  (Provider)  │ │  (Provider) │  │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └─────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      Data Layer                                        │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                   │  │
│  │  │   SQLite     │ │  sqlite-vec  │ │    FTS5      │                   │  │
│  │  │    (GRDB)    │ │  (vectors)   │ │   (search)   │                   │  │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     External Services (via Providers)                        │
│         Kimi API    OpenAI API    Anthropic API    Local Ollama             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔌 Plugin System Architecture

### Philosophy

- **Everything is a plugin** — Core features ship as plugins, not hardcoded
- **Dynamic loading** — Load/unload without app restart
- **Event-driven** — Pub/sub communication between plugins
- **Sandboxed** — Permission-based security model
- **Hot-swappable** — Replace AI providers without code changes

### Plugin Protocol Hierarchy

```swift
// ═══════════════════════════════════════════════════════════════════════════
// BASE PROTOCOL (All plugins implement)
// ═══════════════════════════════════════════════════════════════════════════

public protocol Plugin: AnyObject {
    /// Unique identifier (reverse DNS: com.example.plugin-name)
    var id: String { get }
    
    /// Human-readable name
    var name: String { get }
    
    /// Semantic version
    var version: String { get }
    
    /// Author/company
    var author: String { get }
    
    /// Required permissions
    var permissions: [PluginPermission] { get }
    
    /// Plugin dependencies (other plugin IDs)
    var dependencies: [String] { get }
    
    /// Called when plugin is loaded
    func initialize(context: PluginContext) async throws
    
    /// Called when plugin is unloaded
    func shutdown() async
    
    /// Return settings view (SwiftUI)
    func settingsView() -> AnyView?
}

// ═══════════════════════════════════════════════════════════════════════════
// SPECIALIZED PROTOCOLS
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────────────────
// AI Provider Plugins (Swappable LLM backends)
// ───────────────────────────────────────────────────────────────────────────
public struct GenerationRequest {
    let prompt: String
    let systemPrompt: String?
    let context: EmailContext?
    let style: WritingStyle?
    let model: String
    let temperature: Double
    let maxTokens: Int
    let stream: Bool
}

public struct GenerationResponse {
    let text: String
    let model: String
    let tokensUsed: Int
    let finishReason: String
}

public protocol AIProviderPlugin: Plugin {
    /// List available models
    func availableModels() async -> [Model]
    
    /// Generate completion
    func generate(request: GenerationRequest) async throws -> GenerationResponse
    
    /// Stream completion (for real-time UI)
    func stream(request: GenerationRequest) -> AsyncThrowingStream<String, Error>
    
    /// Validate API key/configuration
    func validateConfiguration() async throws -> Bool
}

// ───────────────────────────────────────────────────────────────────────────
// Analysis Plugins (Process emails, extract insights)
// ───────────────────────────────────────────────────────────────────────────
public struct AnalysisResult {
    let pluginId: String
    let emailId: String
    let insights: [Insight]
    let metadata: [String: AnyCodable]
    let confidence: Double
}

public protocol AnalysisPlugin: Plugin {
    /// Analyze a single email
    func analyze(email: Email) async throws -> AnalysisResult
    
    /// Analyze writing style from corpus
    func analyzeStyle(emails: [Email]) async throws -> WritingStyle
    
    /// Called when new email arrives
    func onEmailReceived(_ email: Email) async
    
    /// Called when email is sent
    func onEmailSent(_ email: Email) async
}

// ───────────────────────────────────────────────────────────────────────────
// Action Plugins (Perform operations on emails/mailbox)
// ───────────────────────────────────────────────────────────────────────────
public enum ActionTrigger {
    case onEmailReceived
    case onEmailSent
    case scheduled(Date)
    case userIdle(TimeInterval)
    case manual
    case event(String)
}

public protocol ActionPlugin: Plugin {
    /// Triggers this action responds to
    var triggers: [ActionTrigger] { get }
    
    /// Execute the action
    func execute(context: ActionContext) async throws -> ActionResult
    
    /// Undo last action (if supported)
    func undo(lastResult: ActionResult) async throws
}

// ───────────────────────────────────────────────────────────────────────────
// Integration Plugins (Connect to external services)
// ───────────────────────────────────────────────────────────────────────────
public protocol IntegrationPlugin: Plugin {
    /// Service name (Slack, Notion, Salesforce, etc.)
    var serviceName: String { get }
    
    /// Connect/authenticate
    func connect() async throws -> ConnectionStatus
    
    /// Disconnect
    func disconnect() async
    
    /// Sync data bidirectionally
    func sync(data: SyncPayload) async throws -> SyncResult
    
    /// Check if connected
    var isConnected: Bool { get }
}

// ───────────────────────────────────────────────────────────────────────────
// UI Plugins (Custom interface elements)
// ───────────────────────────────────────────────────────────────────────────
public enum UIPanel {
    case composeSidebar       // Right panel in compose window
    case composeToolbar       // Toolbar button/menu
    case mainWindow           // Standalone window
    case settings             // Settings tab
    case menuBar              // Menu bar extra
}

public protocol UIPlugin: Plugin {
    /// UI panels provided by this plugin
    func panels() -> [(UIPanel, AnyView)]
    
    /// Compose window toolbar item
    func toolbarItem() -> ToolbarItem?
    
    /// Keyboard shortcuts
    func shortcuts() -> [KeyboardShortcut]
}
```

### Event System (Pub/Sub)

```swift
// ═══════════════════════════════════════════════════════════════════════════
// MAIL EVENTS (Plugins subscribe to these)
// ═══════════════════════════════════════════════════════════════════════════

public enum MailEvent {
    // Lifecycle
    case appLaunched
    case appWillTerminate
    
    // Email Events
    case emailReceived(Email, folder: String)
    case emailSent(Email)
    case emailDeleted(Email)
    case emailMoved(Email, from: String, to: String)
    case emailFlagged(Email, flagged: Bool)
    case emailRead(Email)
    
    // Compose Events
    case composeStarted(ComposeContext)
    case composeContentChanged(String)
    case composeFinished(ComposeResult)
    case replyGenerated(ResponseSuggestion)
    
    // User Events
    case userAction(UserAction)
    case userIdle(TimeInterval)
    case userReturned
    
    // System Events
    case networkStatusChanged(NetworkStatus)
    case preferencesChanged([String: Any])
}

// Event subscription
public protocol EventSubscriber: AnyObject {
    func handle(event: MailEvent) async
}

// Event bus interface (provided to plugins)
public protocol EventBus {
    func subscribe(_ subscriber: EventSubscriber, to events: [MailEvent.Type])
    func unsubscribe(_ subscriber: EventSubscriber)
    func publish(_ event: MailEvent)
}
```

### Plugin Manifest

Each plugin includes a `manifest.json`:

```json
{
  "$schema": "https://kimimail.app/plugin-schema/v1.json",
  "id": "com.example.smart-archive",
  "name": "Smart Archive",
  "version": "1.2.0",
  "minAppVersion": "1.0.0",
  "author": {
    "name": "Example Developer",
    "email": "dev@example.com",
    "url": "https://example.com"
  },
  "description": "AI-powered email archiving based on content analysis",
  "category": "productivity",
  "permissions": [
    "read_emails",
    "modify_folders",
    "background_processing",
    "send_notifications"
  ],
  "hooks": [
    "email_received",
    "user_idle"
  ],
  "dependencies": [
    "core.ai"
  ],
  "entryPoint": "SmartArchivePlugin",
  "resources": {
    "icon": "icon.png",
    "localizations": ["en", "de", "ja"]
  },
  "configuration": {
    "schema": "config-schema.json",
    "defaults": {
      "confidenceThreshold": 0.8,
      "archiveDelay": 3600
    }
  }
}
```

---

## 🗄️ Database Schema

### Core Tables

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- PLUGIN REGISTRY
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE plugins (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    author TEXT,
    enabled BOOLEAN DEFAULT 1,
    permissions TEXT,           -- JSON array
    settings TEXT,              -- JSON blob
    install_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_enabled TIMESTAMP,
    bundle_path TEXT
);

-- Plugin-specific key-value storage
CREATE TABLE plugin_data (
    plugin_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value BLOB,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (plugin_id, key),
    FOREIGN KEY (plugin_id) REFERENCES plugins(id) ON DELETE CASCADE
);

-- Plugin event audit log
CREATE TABLE plugin_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plugin_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT,               -- JSON
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plugin_id) REFERENCES plugins(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- EMAIL STORAGE
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE emails (
    id TEXT PRIMARY KEY,        -- UUID
    message_id TEXT UNIQUE,     -- Email Message-ID header
    thread_id TEXT,             -- Conversation thread
    
    -- Content
    subject TEXT,
    body_plain TEXT,
    body_html TEXT,
    preview TEXT,               -- First 200 chars
    
    -- Addresses
    sender_name TEXT,
    sender_email TEXT,
    recipients_to TEXT,         -- JSON array
    recipients_cc TEXT,         -- JSON array
    recipients_bcc TEXT,        -- JSON array
    
    -- Metadata
    sent_date TIMESTAMP,
    received_date TIMESTAMP,
    folder TEXT,
    account_id TEXT,
    
    -- Status
    is_read BOOLEAN DEFAULT 0,
    is_flagged BOOLEAN DEFAULT 0,
    has_attachments BOOLEAN DEFAULT 0,
    
    -- AI processing
    embedding_version INTEGER,
    processed_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Full-text search
CREATE VIRTUAL TABLE emails_fts USING fts5(
    subject,
    body_plain,
    content='emails',
    content_rowid='id'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER emails_ai AFTER INSERT ON emails BEGIN
    INSERT INTO emails_fts(rowid, subject, body_plain)
    VALUES (new.id, new.subject, new.body_plain);
END;

CREATE TRIGGER emails_ad AFTER DELETE ON emails BEGIN
    INSERT INTO emails_fts(emails_fts, rowid, subject, body_plain)
    VALUES ('delete', old.id, old.subject, old.body_plain);
END;

CREATE TRIGGER emails_au AFTER UPDATE ON emails BEGIN
    INSERT INTO emails_fts(emails_fts, rowid, subject, body_plain)
    VALUES ('delete', old.id, old.subject, old.body_plain);
    INSERT INTO emails_fts(rowid, subject, body_plain)
    VALUES (new.id, new.subject, new.body_plain);
END;

-- ═══════════════════════════════════════════════════════════════════════════
-- PLUGIN-EXTENSIBLE METADATA
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE email_metadata (
    email_id TEXT NOT NULL,
    plugin_id TEXT NOT NULL,
    metadata TEXT NOT NULL,     -- JSON blob
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (email_id, plugin_id),
    FOREIGN KEY (email_id) REFERENCES emails(id) ON DELETE CASCADE,
    FOREIGN KEY (plugin_id) REFERENCES plugins(id) ON DELETE CASCADE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- WRITING STYLE PROFILES
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE writing_profiles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,         -- "Professional", "Casual", "Default"
    
    -- Style metrics (0.0 - 1.0)
    formality_score REAL,
    friendliness_score REAL,
    brevity_score REAL,
    enthusiasm_score REAL,
    
    -- Linguistic features
    avg_sentence_length REAL,
    avg_word_length REAL,
    vocabulary_richness REAL,   -- Type-token ratio
    
    -- Patterns (JSON)
    common_phrases TEXT,        -- ["Looking forward to", "Best regards"]
    greeting_patterns TEXT,     -- ["Hi {name}", "Hello"]
    closing_patterns TEXT,      -- ["Best", "Cheers", "Regards"]
    signature_patterns TEXT,    -- Learned signatures
    transition_phrases TEXT,    -- ["Furthermore", "However"]
    
    -- Source data
    email_count INTEGER,        -- How many emails analyzed
    date_range_start TIMESTAMP,
    date_range_end TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Versioning
    version INTEGER DEFAULT 1
);

-- ═══════════════════════════════════════════════════════════════════════════
-- RESPONSE TEMPLATES (Learned & Manual)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE response_templates (
    id TEXT PRIMARY KEY,
    name TEXT,
    template_text TEXT NOT NULL,
    
    -- Trigger conditions
    trigger_keywords TEXT,      -- JSON array ["budget", "meeting"]
    trigger_subjects TEXT,      -- Regex patterns for subjects
    context_pattern TEXT,       -- Regex for email body matching
    
    -- Style association
    style_profile_id TEXT,
    
    -- Usage stats
    usage_count INTEGER DEFAULT 0,
    last_used TIMESTAMP,
    
    -- Source
    source_plugin_id TEXT,
    is_learned BOOLEAN DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (style_profile_id) REFERENCES writing_profiles(id),
    FOREIGN KEY (source_plugin_id) REFERENCES plugins(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- VECTOR EMBEDDINGS (for RAG/semantic search)
-- ═══════════════════════════════════════════════════════════════════════════
-- Using sqlite-vec extension
CREATE VIRTUAL TABLE email_embeddings USING vec0(
    email_id TEXT PRIMARY KEY,
    embedding FLOAT[768]        -- 768-dim for mpnet, 1536 for OpenAI
);

-- ═══════════════════════════════════════════════════════════════════════════
-- ACTIONS LOG (for undo, audit, analytics)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE actions_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plugin_id TEXT NOT NULL,
    action_type TEXT NOT NULL,  -- "archive", "move", "generate_reply"
    target_email_id TEXT,
    before_state TEXT,          -- JSON snapshot
    after_state TEXT,           -- JSON snapshot
    user_approved BOOLEAN,      -- Was this AI-suggested and user-approved?
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (plugin_id) REFERENCES plugins(id),
    FOREIGN KEY (target_email_id) REFERENCES emails(id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTACTS (enriched from emails)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE contacts (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    
    -- Interaction stats
    email_count_received INTEGER DEFAULT 0,
    email_count_sent INTEGER DEFAULT 0,
    last_contacted TIMESTAMP,
    first_contacted TIMESTAMP,
    
    -- Relationship strength (calculated)
    relationship_score REAL,
    
    -- AI-enriched data
    company TEXT,
    role TEXT,
    topics TEXT,                -- JSON ["project-x", "budget"]
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════════════════════
-- THREADS (conversation tracking)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE threads (
    id TEXT PRIMARY KEY,
    subject_normalized TEXT,    -- "Re:", "Fwd:" stripped
    participants TEXT,          -- JSON array of email addresses
    email_count INTEGER DEFAULT 0,
    last_activity TIMESTAMP,
    summary TEXT,               -- AI-generated thread summary
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDICES
-- ═══════════════════════════════════════════════════════════════════════════
CREATE INDEX idx_emails_sender ON emails(sender_email);
CREATE INDEX idx_emails_date ON emails(sent_date);
CREATE INDEX idx_emails_folder ON emails(folder);
CREATE INDEX idx_emails_thread ON emails(thread_id);
CREATE INDEX idx_emails_unread ON emails(is_read) WHERE is_read = 0;
CREATE INDEX idx_actions_plugin ON actions_log(plugin_id);
CREATE INDEX idx_actions_date ON actions_log(executed_at);
```

---

## 📦 Built-in Plugin Catalog

### Core Plugins (Shipped with app)

| Plugin | Type | Description |
|--------|------|-------------|
| **StyleLearner** | Analysis | Analyzes sent emails to build your writing profile |
| **ResponseGenerator** | AI Consumer | Generates contextual replies using your style |
| **KnowledgeBase** | Service | Manages SQLite database, provides query interface |
| **PrivacyGuard** | Security | Redacts PII before sending to cloud AI |
| **TemplateEngine** | Utility | Learns and suggests response templates |
| **SmartSearch** | Analysis | Natural language email search with embeddings |

### AI Provider Plugins

| Plugin | Provider | Best For |
|--------|----------|----------|
| **KimiProvider** | Moonshot AI (Kimi) | Balanced performance, good context |
| **OpenAIProvider** | OpenAI (GPT-4) | Highest quality, expensive |
| **AnthropicProvider** | Anthropic (Claude) | Long context, safety-focused |
| **OllamaProvider** | Local (Ollama) | Privacy, no API costs, offline |
| **AzureProvider** | Azure OpenAI | Enterprise, compliance |

### Optional Premium Plugins

| Plugin | Type | Description | Category |
|--------|------|-------------|----------|
| **FollowUpReminder** | Action | Detects and reminds about pending replies | Productivity |
| **SmartArchive** | Action | Auto-archives based on learned patterns | Productivity |
| **MeetingScheduler** | Integration | Detects scheduling intent, suggests times | Productivity |
| **Summarizer** | Analysis | TL;DR for long threads | AI Features |
| **SentimentGuard** | Analysis | Warns about harsh tone before sending | AI Features |
| **TranslationBridge** | AI Consumer | Real-time translation preserving tone | AI Features |
| **SmartCC** | Analysis | Suggests who to CC based on content | Intelligence |
| **ContextAwareness** | Analysis | Reads calendar, suggests appropriate responses | Intelligence |
| **RelationshipTracker** | Analysis | Reminds you to reach out to contacts | Intelligence |
| **PhishingDetector** | Security | ML-based suspicious email detection | Security |
| **ComplianceGuard** | Security | GDPR/privacy warnings | Security |
| **NotionSync** | Integration | Save emails to Notion | Integrations |
| **SlackBridge** | Integration | Forward to Slack channels | Integrations |
| **CRMConnector** | Integration | Salesforce/HubSpot sync | Integrations |
| **CalendarSync** | Integration | Create events from emails | Integrations |
| **SharedTemplates** | Integration | Team template sharing | Collaboration |
| **EmailAnalytics** | Analysis | Response time, productivity metrics | Analytics |
| **InboxZeroCoach** | Analysis | Daily reports, coaching tips | Productivity |
| **VoiceComposer** | UI | Dictate emails, AI cleanup | Accessibility |
| **AttachmentIntelligence** | Analysis | Detect missing attachments | Utility |

---

## 🎯 Feature Deep-Dives

### 1. Style Learning System

```
┌─────────────────────────────────────────────────────────────────┐
│                    STYLE LEARNING PIPELINE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │ Sent Emails  │────▶│ Preprocessor │────▶│  Analyzer    │    │
│  │   (Last 90d) │     │ (clean HTML, │     │ (extract     │    │
│  │              │     │ strip quotes)│     │  features)   │    │
│  └──────────────┘     └──────────────┘     └──────┬───────┘    │
│                                                    │            │
│                           ┌────────────────────────┘            │
│                           ▼                                     │
│              ┌──────────────────────────┐                      │
│              │    FEATURE EXTRACTION     │                      │
│              ├──────────────────────────┤                      │
│              │ • Sentence length stats   │                      │
│              │ • Word choice analysis    │                      │
│              │ • Greeting patterns       │                      │
│              │ • Closing patterns        │                      │
│              │ • Signature detection     │                      │
│              │ • Formality markers       │                      │
│              │ • Transition phrases      │                      │
│              └────────────┬─────────────┘                      │
│                           │                                     │
│                           ▼                                     │
│              ┌──────────────────────────┐                      │
│              │    STYLE PROFILE          │                      │
│              ├──────────────────────────┤                      │
│              │ Formality: 0.7            │                      │
│              │ Friendliness: 0.6         │                      │
│              │ Avg sentence: 15 words    │                      │
│              │ Greetings: ["Hi", "Hello"]│                      │
│              │ Closings: ["Best", "Cheers"│                      │
│              └──────────────────────────┘                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Runs weekly in background
- Extracts formality, brevity, enthusiasm scores
- Identifies signature patterns
- Learns domain-specific vocabulary
- Multiple profiles (work, personal, client-specific)

### 2. Response Generation (RAG Pipeline)

```
┌─────────────────────────────────────────────────────────────────┐
│                 RESPONSE GENERATION PIPELINE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  INCOMING EMAIL                                                  │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              RETRIEVAL (RAG)                             │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │  Semantic   │  │  Keyword    │  │  Thread     │     │    │
│  │  │  Search     │  │  Match      │  │  History    │     │    │
│  │  │  (top-5)    │  │  (subject)  │  │  (context)  │     │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │    │
│  └────────────────────┬────────────────────────────────────┘    │
│                       │                                          │
│                       ▼                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              PROMPT CONSTRUCTION                         │    │
│  │                                                          │    │
│  │  System: "You are writing as {user}. Style: {profile}"   │    │
│  │                                                          │    │
│  │  Context: "You previously replied to similar emails:"    │    │
│  │  {retrieved_examples}                                    │    │
│  │                                                          │    │
│  │  Task: "Reply to this email maintaining the same tone:"  │    │
│  │  {incoming_email}                                        │    │
│  │                                                          │    │
│  │  Generate 3 variants: formal, casual, brief              │    │
│  └────────────────────┬────────────────────────────────────┘    │
│                       │                                          │
│                       ▼                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              AI GENERATION                               │    │
│  │              (via configured provider)                   │    │
│  └────────────────────┬────────────────────────────────────┘    │
│                       │                                          │
│                       ▼                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              POST-PROCESSING                             │    │
│  │  • Ensure signature matches profile                      │    │
│  │  • Apply any user corrections (learn from edits)         │    │
│  │  • Check for missing attachments mentioned                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Follow-Up Reminder System

```swift
// Detects emails needing follow-up
enum FollowUpSignal {
    case explicit("I'll get back to you")
    case implicit(questionAsked, noResponse: Bool)
    case deadlineMentioned(Date)
    case commitmentMade(String)
}

// Example detection:
// "Let me check with the team and circle back" → Reminder in 24h
// "Can you send me the report by Friday?" → Reminder on Friday
// "Following up on my previous email" → Priority boost
```

### 4. PrivacyGuard (PII Redaction)

```swift
enum SensitiveDataType {
    case email(String)
    case phone(String)
    case ssn(String)
    case creditCard(String)
    case apiKey(String)
    case password(String)
}

// Before sending to cloud AI:
// "My email is john@company.com" → "My email is [EMAIL_1]"
// Then restore after generation
```

---

## 📁 Project Structure

```
MailAssistant/
├── 📁 MailAssistant.xcodeproj
│
├── 📁 App/                                    # Main app target
│   ├── 📁 Sources/
│   │   ├── 📄 MailAssistantApp.swift      # App entry point
│   │   ├── 📁 Windows/
│   │   │   ├── 📄 MainWindow.swift
│   │   │   ├── 📄 OnboardingWindow.swift
│   │   │   └── 📄 PluginStoreWindow.swift
│   │   ├── 📁 Views/
│   │   │   ├── 📁 Settings/
│   │   │   │   ├── 📄 GeneralSettings.swift
│   │   │   │   ├── 📄 AIProviderSettings.swift
│   │   │   │   ├── 📄 PrivacySettings.swift
│   │   │   │   └── 📄 PluginSettings.swift
│   │   │   ├── 📁 Dashboard/
│   │   │   │   ├── 📄 DashboardView.swift
│   │   │   │   ├── 📄 EmailStatsCard.swift
│   │   │   │   └── 📄 PluginStatusCard.swift
│   │   │   └── 📁 Onboarding/
│   │   │       ├── 📄 WelcomeView.swift
│   │   │       ├── 📄 MailAccessView.swift
│   │   │       ├── 📄 AISetupView.swift
│   │   │       └── 📄 ImportView.swift
│   │   └── 📁 Managers/
│   │       ├── 📄 AppStateManager.swift
│   │       └── 📄 UpdateManager.swift
│   └── 📁 Resources/
│       ├── 📁 Assets.xcassets/
│       └── 📄 Info.plist
│
├── 📁 MailExtension/                          # Mail App Extension
│   ├── 📁 Sources/
│   │   ├── 📄 MailExtension.swift             # Extension entry
│   │   ├── 📄 ComposeHandler.swift            # Compose window hook
│   │   ├── 📁 UI/
│   │   │   ├── 📄 SuggestionPanel.swift       # Main suggestion UI
│   │   │   ├── 📄 ToneSelector.swift          # Formal/Casual/Brief
│   │   │   ├── 📄 VariantCards.swift          # Multiple suggestions
│   │   │   └── 📄 QuickActionsBar.swift       # Accept/Edit/Regenerate
│   │   └── 📁 Injectors/
│   │       ├── 📄 ComposeInjector.swift       # Injects into Mail UI
│   │       └── 📄 ToolbarInjector.swift
│   └── 📁 Resources/
│       └── 📄 Info.plist
│
├── 📁 MailAssistantService/                   # XPC Background Service
│   ├── 📁 Sources/
│   │   ├── 📄 main.swift
│   │   ├── 📁 Service/
│   │   │   ├── 📄 ServiceDelegate.swift
│   │   │   ├── 📄 XPCInterface.swift
│   │   │   └── 📄 LifecycleManager.swift
│   │   ├── 📁 PluginSystem/
│   │   │   ├── 📄 PluginManager.swift         # Core plugin management
│   │   │   ├── 📄 PluginLoader.swift          # Dynamic loading
│   │   │   ├── 📄 EventBus.swift              # Pub/sub system
│   │   │   ├── 📄 PluginSandbox.swift         # Security isolation
│   │   │   └── 📄 PermissionManager.swift
│   │   ├── 📁 Database/
│   │   │   ├── 📄 DatabaseManager.swift       # GRDB wrapper
│   │   │   ├── 📄 Migrations/
│   │   │   ├── 📁 Models/
│   │   │   └── 📄 VectorStore.swift           # sqlite-vec integration
│   │   ├── 📁 AI/
│   │   │   ├── 📄 AIProviderManager.swift     # Provider routing
│   │   │   ├── 📄 PromptEngine.swift          # Prompt construction
│   │   │   └── 📄 RAGEngine.swift             # Retrieval system
│   │   ├── 📁 MailProcessing/
│   │   │   ├── 📄 MailImporter.swift
│   │   │   ├── 📄 StyleAnalyzer.swift
│   │   │   └── 📄 ThreadTracker.swift
│   │   └── 📁 Background/
│   │       ├── 📄 BackgroundTaskManager.swift
│   │       └── 📄 ScheduledJobs.swift
│   └── 📁 Resources/
│
├── 📁 Plugins/                                # Built-in plugins
│   ├── 📁 Core/
│   │   ├── 📁 StyleLearner/
│   │   │   ├── 📄 StyleLearnerPlugin.swift
│   │   │   ├── 📄 FeatureExtractor.swift
│   │   │   └── 📄 manifest.json
│   │   ├── 📁 ResponseGenerator/
│   │   │   ├── 📄 ResponseGeneratorPlugin.swift
│   │   │   ├── 📄 SuggestionEngine.swift
│   │   │   └── 📄 manifest.json
│   │   ├── 📁 KnowledgeBase/
│   │   │   ├── 📄 KnowledgeBasePlugin.swift
│   │   │   └── 📄 manifest.json
│   │   ├── 📁 PrivacyGuard/
│   │   │   ├── 📄 PrivacyGuardPlugin.swift
│   │   │   ├── 📄 PIIRedactor.swift
│   │   │   └── 📄 manifest.json
│   │   └── 📁 TemplateEngine/
│   │       ├── 📄 TemplateEnginePlugin.swift
│   │       └── 📄 manifest.json
│   │
│   ├── 📁 AIProviders/
│   │   ├── 📁 KimiProvider/
│   │   │   ├── 📄 KimiProviderPlugin.swift
│   │   │   ├── 📄 KimiAPI.swift
│   │   │   └── 📄 manifest.json
│   │   ├── 📁 OpenAIProvider/
│   │   ├── 📁 AnthropicProvider/
│   │   └── 📁 OllamaProvider/
│   │
│   └── 📁 Optional/
│       ├── 📁 FollowUpReminder/
│       ├── 📁 SmartArchive/
│       ├── 📁 MeetingScheduler/
│       ├── 📁 Summarizer/
│       ├── 📁 SentimentGuard/
│       ├── 📁 TranslationBridge/
│       ├── 📁 NotionSync/
│       └── 📁 SlackBridge/
│
├── 📁 PluginAPI/                              # Public plugin SDK
│   └── 📁 Sources/
│       ├── 📄 PluginProtocol.swift
│       ├── 📄 AIProviderProtocol.swift
│       ├── 📄 AnalysisProtocol.swift
│       ├── 📄 ActionProtocol.swift
│       ├── 📄 IntegrationProtocol.swift
│       ├── 📄 UIProtocol.swift
│       ├── 📁 Events/
│       │   ├── 📄 MailEvent.swift
│       │   └── 📄 EventBus.swift
│       ├── 📁 Models/
│       │   ├── 📄 Email.swift
│       │   ├── 📄 WritingStyle.swift
│       │   ├── 📄 ResponseSuggestion.swift
│       │   └── 📄 Contact.swift
│       └── 📁 Permissions/
│           └── 📄 PluginPermission.swift
│
├── 📁 Shared/                                 # Shared code
│   └── 📁 Sources/
│       ├── 📁 Utilities/
│       │   ├── 📄 Logger.swift
│       │   ├── 📄 Keychain.swift
│       │   └── 📄 NetworkMonitor.swift
│       └── 📁 Extensions/
│           └── 📄 String+Extensions.swift
│
├── 📁 Tests/
│   ├── 📁 UnitTests/
│   ├── 📁 IntegrationTests/
│   └── 📁 PluginTests/
│
├── 📁 Documentation/
│   ├── 📄 ARCHITECTURE.md
│   ├── 📄 PLUGIN_DEVELOPMENT.md
│   ├── 📄 API_REFERENCE.md
│   └── 📄 DEPLOYMENT.md
│
└── 📁 Scripts/
    ├── 📄 build.sh
    ├── 📄 sign.sh
    └── 📄 release.sh
```

---

## 🚀 Implementation Roadmap

### Phase 1: Foundation (Weeks 1-3)
**Goal:** Working skeleton with plugin system

| Week | Tasks |
|------|-------|
| 1 | Xcode project setup, 3 targets, basic XPC communication |
| 2 | Database layer (GRDB), migrations, core tables |
| 3 | Plugin system core (manager, loader, event bus, sandbox) |

**Deliverable:** Service runs, loads/unloads test plugins

### Phase 2: Core Features (Weeks 4-6)
**Goal:** Basic AI response generation

| Week | Tasks |
|------|-------|
| 4 | KimiProvider plugin, API client, streaming support |
| 5 | StyleLearner plugin, basic analysis pipeline |
| 6 | ResponseGenerator plugin, simple RAG, Mail Extension UI |

**Deliverable:** Suggests responses in Mail compose window

### Phase 3: Intelligence (Weeks 7-9)
**Goal:** Smart features, multiple providers

| Week | Tasks |
|------|-------|
| 7 | Vector embeddings (sqlite-vec), semantic search |
| 8 | OpenAI, Anthropic, Ollama providers |
| 9 | PrivacyGuard, TemplateEngine, better RAG |

**Deliverable:** Privacy mode, multiple AI options, learned templates

### Phase 4: Plugin Ecosystem (Weeks 10-12)
**Goal:** Rich feature set through plugins

| Week | Tasks |
|------|-------|
| 10 | FollowUpReminder, SmartArchive, MeetingScheduler |
| 11 | Summarizer, SentimentGuard, TranslationBridge |
| 12 | NotionSync, SlackBridge, plugin store foundation |

**Deliverable:** 15+ working plugins, plugin marketplace UI

### Phase 5: Polish & Ship (Weeks 13-14)
**Goal:** Production-ready

| Week | Tasks |
|------|-------|
| 13 | Performance optimization, memory profiling, stress testing |
| 14 | Security audit, documentation, beta testing, distribution setup |

**Deliverable:** Signed, notarized app ready for distribution

---

## 💰 Monetization Model

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | Core plugins (StyleLearner, ResponseGenerator, 1 AI provider, 1000 emails stored) |
| **Pro** | $9/mo | All AI providers, all premium plugins, unlimited history, priority support |
| **Team** | $19/user/mo | Shared templates, admin dashboard, usage analytics, SSO, team style profiles |
| **Enterprise** | Custom | Self-hosted AI, custom plugins, dedicated support, compliance features |

---

## 🔒 Security & Privacy

### Data Handling
- **Emails:** Never leave your Mac unless explicitly configured
- **Embeddings:** Stored locally in SQLite
- **API calls:** Only send email content to AI provider you choose
- **PII:** Automatically redacted before cloud processing (optional)

### Sandboxing
- Plugins run in separate process space
- Permission-based access (read_emails, modify_folders, etc.)
- Code signature verification for third-party plugins
- Network access restricted by permission

### Local-First Mode
```swift
// Privacy-first configuration
let config = PrivacyConfig(
    mode: .localOnly,           // Only use Ollama/local models
    cloudSync: false,           // No cloud storage
    analytics: false,           // No telemetry
    embeddingModel: .local      // Local embeddings only
)
```

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI |
| **Database** | SQLite via GRDB |
| **Vector Search** | sqlite-vec |
| **XPC** | NSXPCConnection |
| **HTTP** | URLSession + async/await |
| **JSON** | Codable |
| **Testing** | XCTest |
| **CI/CD** | GitHub Actions |
| **Updates** | Sparkle |
| **Crash Reporting** | Sentry (optional) |

---

## 📋 Next Steps

1. **Review this plan** — Provide feedback on scope, features, priorities
2. **Decide on AI providers** — Start with Kimi only or multiple from day 1?
3. **Choose initial plugins** — Which optional plugins are must-haves for MVP?
4. **Set up development environment** — Xcode project, dependencies
5. **Begin Phase 1** — Foundation and plugin system

---

*This document is a living specification. As we build, we'll refine based on technical constraints and user feedback.*
