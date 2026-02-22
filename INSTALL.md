# MailAssistantService Installation Guide

## Prerequisites

- macOS 14.0+
- Xcode 16.0+
- Apple Developer Account (for code signing)
- Mail.app (built-in macOS mail client)

## Installation Steps

### 1. Build the Project

```bash
# Navigate to project directory
cd /Users/rabitem/Dokumente/Projekte/MailAssistantService

# Open in Xcode
open MailAssistant.xcodeproj
```

In Xcode:
1. Select the **MailAssistant-All** aggregate target
2. Select your Mac as the destination
3. Build (⌘+B)

### 2. Code Signing Setup

1. In Xcode, select the MailAssistant project in navigator
2. For each target (MailAssistant, MailExtension, MailAssistantService):
   - Select the target
   - Go to **Signing & Capabilities**
   - Set **Team** to your Apple Developer team
   - Verify Bundle Identifier is `de.rabitem.MailAssistant.*`

### 3. Run the Main App

1. Select **MailAssistant** target
2. Run (⌘+R)
3. Complete the onboarding:
   - Grant Mail access permissions
   - Configure AI provider (Kimi API key)
   - Import existing emails (optional)

### 4. Enable Mail Extension

1. Open **Mail.app**
2. Go to **Settings** → **Extensions**
3. Find **MailAssistant** and enable it
4. Restart Mail.app

### 5. Grant Required Permissions

The app needs these permissions:

#### Full Disk Access (for email import)
1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Add **MailAssistant** app
3. Restart MailAssistant

#### Accessibility (optional, for enhanced UI)
1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Add **MailAssistant** app

### 6. Verify Installation

1. Open Mail.app
2. Compose a new email or reply
3. You should see the MailAssistant suggestion panel appear
4. Try the keyboard shortcut ⌘⇧G to generate suggestions

## Troubleshooting

### Extension Not Showing
- Verify extension is enabled in Mail Settings → Extensions
- Check Console.app for errors
- Restart Mail.app

### No Suggestions Appearing
- Verify AI provider is configured (API key set)
- Check XPC service is running (Activity Monitor)
- Review MailAssistant logs in Console.app

### Build Errors
- Clean build folder (⌘+Shift+K)
- Ensure all dependencies are resolved
- Check Swift version (6.0+)

### Permission Denied
- Grant Full Disk Access in System Settings
- Check that entitlements are properly signed

## Uninstall

1. Remove from **System Settings** → **Extensions**
2. Quit MailAssistant app
3. Delete app from Applications folder
4. Remove data: `rm -rf ~/Library/Application\ Support/MailAssistant`

## Support

For issues, check:
- Console.app logs
- `~/Library/Logs/MailAssistant/`
- GitHub Issues: https://github.com/rabitem/MailAssistantService/issues
