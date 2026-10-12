# AI Usage

AI Usage is a macOS menu-bar app that shows how much of your Claude, Codex, Cursor, and Grok Bot allowances you have used.

The icon lives in the menu bar. It is not a Control Center widget — a menu bar extra cannot be dropped into Control Center. Command-drag the icon to reorder it. To hide it, use System Settings → Menu Bar.

When a provider has reported usage, the menu-bar icon shows the hottest percent, including 0%. Before any usage has loaded, it shows a gauge icon.

## Requirements

- macOS 15 or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Generate, build, and run

```bash
xcodegen generate
xcodebuild -scheme AIUsageWidget -destination 'platform=macOS' -derivedDataPath .build build
open ".build/Build/Products/Debug/AI Usage.app"
```

## Tests

```bash
xcodebuild -scheme AIUsageWidget -destination 'platform=macOS' -derivedDataPath .build test
```

## Providers

### Claude

Claude needs a session cookie you copy once. In claude.ai, open DevTools → Network, reload https://claude.ai/settings/usage, and copy that usage request's Cookie header (or only the `sessionKey` value). Paste it into the Claude section. The cookie is stored in the Keychain on this Mac.

### Codex

Install the Codex CLI and run `codex login`. The app asks the local `codex app-server` for rate limits. It does not read `~/.codex/auth.json`, and it does not ask for an Admin API key.

### Cursor

If you are signed in to the Cursor app, AI Usage reads the local session and requests usage itself. If that session is missing, paste a Cursor access token in the Cursor section.

### Grok Bot

Grok Bot reuses the Cursor login. Sign in to Cursor, or set the Cursor token. There is no separate Grok API key.

Launch at login and Quit live under Settings at the bottom of the popover.
