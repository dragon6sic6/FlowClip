# FlowClip 📋

A beautiful, Apple-inspired clipboard manager for macOS with liquid glass UI.

## Features
- **Hold ⌘V** to reveal your clipboard history with a smooth animated picker
- **Liquid glass design** — frosted blur, subtle borders, spring animations
- **Unlimited items** per session
- **30-minute sessions** by default (fully configurable)
- **Per-item delete** — hover any item and tap the ✕
- **Clear all** from within the picker with one click
- **Source app label** — see which app you copied from
- **Search** — type while picker is open to filter items
- Lives in the **menu bar** — no dock icon, zero friction

## Building in Xcode

### Requirements
- macOS 13+
- Xcode 15+

### Steps

1. Open Xcode → **File → New → Project**
2. Choose **macOS → App**
3. Set:
   - Product Name: `FlowClip`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Uncheck "Include Tests"
4. Delete the auto-generated `ContentView.swift` and `FlowClipApp.swift`
5. Drag all `.swift` files from this folder into the Xcode project
6. In **Signing & Capabilities**:
   - Disable App Sandbox (or use the provided `.entitlements` file)
   - Sign with your Apple ID (personal team is fine for local use)
7. Set minimum deployment to **macOS 13.0**
8. **Build & Run** (⌘R)

### Permissions Required
On first launch, macOS will ask for **Accessibility access** — this is required for global keyboard monitoring (intercepting Cmd+V system-wide).

Go to: **System Settings → Privacy & Security → Accessibility → enable FlowClip**

## Usage

| Action | How |
|--------|-----|
| Copy to history | ⌘C as normal |
| Show picker | Hold ⌘V for ~0.2 seconds |
| Paste item | Click it in the picker |
| Delete one item | Hover → click ✕ |
| Clear all | Click "Clear" in picker header |
| Settings | Menu bar icon → Settings... |

## Architecture

```
FlowClipApp.swift      — App entry, NSApplicationDelegate, menu bar setup
ClipboardManager.swift — Polls NSPasteboard every 0.25s, manages session
KeyboardMonitor.swift  — Global ⌘V intercept via NSEvent monitors
PickerWindow.swift     — Borderless NSWindow hosting the floating picker
PickerView.swift       — SwiftUI liquid glass UI with animations
SettingsView.swift     — Session duration settings panel
```
