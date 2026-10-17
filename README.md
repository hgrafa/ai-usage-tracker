# AI Usage

AI Usage is a macOS menu-bar app that shows how much of your Claude, Codex, Cursor, Grok Bot, OpenRouter, DeepSeek, and Moonshot allowances you have used.

## Install

The app needs macOS 15 or later. Download [AI-Usage.dmg](https://github.com/hgrafa/ai-usage-widget/releases/latest/download/AI-Usage.dmg) from the [latest release](https://github.com/hgrafa/ai-usage-widget/releases/latest), open it, and drag AI Usage into Applications.

The build is ad-hoc signed, so the first launch is blocked by Gatekeeper. Open AI Usage once, then go to System Settings › Privacy & Security and choose Open Anyway. After that it stays in the menu bar. There is no Dock icon.

A product page lives in [`docs/`](docs/index.html). GitHub Pages serves it from the `docs` folder on `main` (repository Settings → Pages → Deploy from a branch).

To publish a disk image, push a tag such as `v0.1.0`. The release workflow builds `AI-Usage.dmg` and attaches it to that GitHub release. Check for Updates in the app reads that release.

The icon lives in the menu bar. It is not a Control Center widget — a menu bar extra cannot be dropped into Control Center. Command-drag the icon to reorder it. To hide it, use System Settings → Menu Bar.

When a provider has reported usage, the menu-bar icon shows the hottest percent, including 0%. Before any usage has loaded, it shows a gauge icon.

## Requirements

- macOS 15 or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Generate, build, and run

```bash
swift scripts/render-branding.swift
xcodegen generate
xcodebuild -scheme AIUsageWidget -destination 'platform=macOS' -derivedDataPath .build build
open ".build/Build/Products/Debug/AI Usage.app"
```

A styled disk image (app icon, background, Applications drop target):

```bash
scripts/package-dmg.sh
open dist/AI-Usage.dmg
```

## Tests

```bash
xcodebuild -scheme AIUsageWidget -destination 'platform=macOS' -derivedDataPath .build test
```

## Providers

### Claude

Claude needs a session cookie you copy once. In claude.ai, open DevTools → Network, reload https://claude.ai/settings/usage, and paste that usage request's Cookie header, `sessionKey=…`, or just the token. The app keeps `sessionKey` and `lastActiveOrg` and drops the rest. It is stored in the Keychain on this Mac.

### Codex

Install the Codex CLI and run `codex login`. The app asks the local `codex app-server` for rate limits. It does not read `~/.codex/auth.json`, and it does not ask for an Admin API key.

### Cursor

If you are signed in to the Cursor app, AI Usage reads the local session and requests usage itself. If that session is missing, paste a Cursor access token in the Cursor section.

### Grok Bot

Grok Bot reuses the Cursor login. Sign in to Cursor, or set the Cursor token. There is no separate Grok API key.

### OpenRouter

Paste an API key from [OpenRouter keys](https://openrouter.ai/settings/keys). The app calls `GET /api/v1/key` and shows that key's spend cap, the tightest budget, and the free-model daily quota. A key with no cap shows today's, this week's, and this month's spend instead of a percent bar. Account-wide credits need a management key, which this app does not ask for.

### DeepSeek

Paste an API key from the [DeepSeek console](https://platform.deepseek.com/api_keys). The app calls `GET /user/balance` and shows the remaining balance. DeepSeek does not return a percent cap, so this row has no meter.

### Moonshot

Paste an API key from [Kimi](https://platform.kimi.ai) or [Moonshot China](https://platform.moonshot.cn). The app calls `GET /v1/users/me/balance`, trying `api.moonshot.ai` and then `api.moonshot.cn`. It shows the remaining balance. Moonshot does not return a percent cap, so this row has no meter.

Launch at login and Quit live under Settings at the bottom of the popover.
