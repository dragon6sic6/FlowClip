# FlowClip

A lightweight clipboard manager for macOS. Copy things, pick from your history, paste faster.

Built by **Mindact**.

---

## How It Works

1. **Copy as usual** - FlowClip runs in the menu bar and quietly saves everything you copy with `⌘C`.
2. **Hold ⌘V to pick** - Tap `⌘V` to paste normally. Hold it down to open a picker overlay showing your clipboard history.
3. **Click to paste** - Select any item from the picker and it gets pasted instantly.

## Features

- **Clipboard history** - Remembers up to 200 copied items per session
- **Quick picker** - Hold `⌘V` to browse and select from history
- **Menu bar history** - Hover over "History" in the menu bar for quick access
- **Smart duplicates** - Optionally removes duplicate entries automatically
- **Session duration** - Auto-clears history after a set time (15 min to forever)
- **Source app labels** - See which app you copied from
- **Search** - Type while picker is open to filter items
- **Lightweight** - No dock icon, no background noise, just a menu bar icon

## Install

1. Download `FlowClip.zip` from [Releases](https://github.com/dragon6sic6/FlowClip/releases) (or build from source)
2. Unzip and drag **FlowClip.app** to your Applications folder
3. Open FlowClip
4. Grant **Accessibility** permission when prompted (required for `⌘V` detection)

> **Note:** macOS requires you to manually enable Accessibility access in **System Settings > Privacy & Security > Accessibility**. Toggle FlowClip ON.

## Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Copy to history | `⌘C` (works everywhere) |
| Open picker | Hold `⌘V` |
| Paste selected item | Click / release `⌘V` |
| Dismiss picker | `Esc` |
| Quick paste from menu | `⌘1` through `⌘9` |

## Settings

Access settings from the menu bar icon > **Settings...** (`⌘,`):

- **Session Duration** - How long to keep history (15 min, 30 min, 1 hour, 2 hours, forever, or custom)
- **Remember** - Maximum number of items to store (5-200)
- **Display in menu** - How many items to show in the History submenu (5-100)
- **Remove duplicates** - Automatically remove older copies of the same text

## Architecture

```
FlowClipApp.swift       - App entry, menu bar, window management
ClipboardManager.swift  - Clipboard polling, history, settings persistence
KeyboardMonitor.swift   - Global ⌘V intercept via NSEvent monitors
PickerWindow.swift      - Borderless NSWindow hosting the floating picker
PickerView.swift        - SwiftUI picker overlay with animations
SettingsView.swift      - Card-based settings UI
WelcomeView.swift       - First-launch onboarding
AboutView.swift         - About window
```

## Build from Source

Requires Xcode 15+ and macOS 13+.

```bash
git clone https://github.com/dragon6sic6/FlowClip.git
cd FlowClip
xcodebuild -scheme FlowClip -configuration Release
```

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission

## License

MIT
