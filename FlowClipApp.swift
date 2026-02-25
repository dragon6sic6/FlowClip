import SwiftUI
import AppKit
import ApplicationServices

@main
struct FlowClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var clipboardManager: ClipboardManager!
    var keyMonitor: KeyboardMonitor!
    var popoverWindow: PickerWindow?
    var settingsWindow: NSWindow?
    private var accessibilityCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        clipboardManager = ClipboardManager.shared
        setupMenuBar()
        checkAccessibilityAndStart()
    }

    // MARK: - Accessibility

    private func checkAccessibilityAndStart() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )

        if trusted {
            startKeyboardMonitor()
            updateMenuStatus()
        } else {
            showAccessibilityAlert()
            accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.accessibilityCheckTimer = nil
                    self?.startKeyboardMonitor()
                    self?.updateMenuStatus()
                }
            }
        }
    }

    private func startKeyboardMonitor() {
        keyMonitor = KeyboardMonitor(clipboardManager: clipboardManager)
        keyMonitor.onShowPicker = { [weak self] in self?.showPicker() }
        keyMonitor.onHidePicker = { [weak self] in self?.hidePicker() }
        keyMonitor.startMonitoring()
    }

    private func showAccessibilityAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "FlowClip Needs Accessibility Permission"
        alert.informativeText = "FlowClip needs Accessibility access to detect Cmd+V.\n\nFind FlowClip in the list and toggle it ON."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }

        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Menu bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "FlowClip")
            button.image?.isTemplate = true
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(NSMenuItem(title: "FlowClip", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let accessOK = AXIsProcessTrusted()
        let accessItem = NSMenuItem(
            title: accessOK ? "Accessibility: Enabled" : "Accessibility: NOT Enabled",
            action: accessOK ? nil : #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessItem.target = self
        menu.addItem(accessItem)

        let countItem = NSMenuItem(
            title: "Clipboard Items: \(ClipboardManager.shared.items.count)",
            action: nil, keyEquivalent: ""
        )
        menu.addItem(countItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit FlowClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func updateMenuStatus() {
        rebuildMenu()
    }

    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "FlowClip Settings"
            settingsWindow?.styleMask = [.titled, .closable, .resizable]
            settingsWindow?.setContentSize(NSSize(width: 400, height: 460))
            settingsWindow?.minSize = NSSize(width: 360, height: 420)
            settingsWindow?.isReleasedWhenClosed = false
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func clearHistory() {
        ClipboardManager.shared.clearAll()
    }

    // MARK: - Picker

    func showPicker() {
        guard ClipboardManager.shared.items.count > 0 else { return }

        if popoverWindow == nil {
            popoverWindow = PickerWindow()
            popoverWindow?.keyboardMonitor = keyMonitor
            popoverWindow?.onDismiss = { [weak self] in
                self?.keyMonitor.resetPickerState()
            }
        }
        popoverWindow?.showPicker()
    }

    func hidePicker() {
        popoverWindow?.hidePicker()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
