import AppKit
import SwiftUI

/// Borderless window that can become key and suppresses system beep.
private class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func noResponder(for eventSelector: Selector) {
        // Suppress NSBeep when responder chain doesn't handle an event
    }
}

class PickerWindow: NSObject {
    private var window: NSWindow?
    private var hostingView: NSHostingView<PickerView>?
    private var clickOutsideMonitor: Any?
    private var previousApp: NSRunningApplication?

    /// Called whenever the picker is dismissed (by selection, click-outside, or escape).
    var onDismiss: (() -> Void)?

    /// Reference to the keyboard monitor so we can use its synthetic paste helper.
    var keyboardMonitor: KeyboardMonitor?

    override init() {
        super.init()
        setupWindow()
    }

    deinit {
        removeClickMonitor()
    }

    private func setupWindow() {
        let pickerView = PickerView(onSelect: { [weak self] item in
            self?.selectItem(item)
        }, onDismiss: { [weak self] in
            self?.dismiss()
        })

        let hosting = NSHostingView(rootView: pickerView)
        self.hostingView = hosting

        let win = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        win.contentView = hosting
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .popUpMenu
        win.hasShadow = true
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        self.window = win
    }

    func showPicker() {
        // Save the app that was active before we steal focus
        previousApp = NSWorkspace.shared.frontmostApplication

        // Recreate view with fresh state
        let pickerView = PickerView(onSelect: { [weak self] item in
            self?.selectItem(item)
        }, onDismiss: { [weak self] in
            self?.dismiss()
        })
        hostingView?.rootView = pickerView

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let winWidth: CGFloat = 560
            let winHeight: CGFloat = min(CGFloat(ClipboardManager.shared.items.count) * 72 + 100, 500)
            let x = screenFrame.midX - winWidth / 2
            let y = screenFrame.midY - winHeight / 2
            window?.setFrame(NSRect(x: x, y: y, width: winWidth, height: winHeight), display: true)
        }

        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1
        })

        // Dismiss on click outside
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let win = self.window, win.isVisible else { return }
            let clickLocation = NSEvent.mouseLocation
            if !win.frame.contains(clickLocation) {
                self.dismiss()
            }
        }
    }

    func hidePicker() {
        removeClickMonitor()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0
        }, completionHandler: {
            self.window?.orderOut(nil)
        })
    }

    /// Dismiss the picker and notify the delegate (AppDelegate / KeyboardMonitor).
    func dismiss() {
        hidePicker()
        onDismiss?()
    }

    private func selectItem(_ item: ClipboardItem) {
        NSLog("FlowClip: selectItem called — \(item.preview.prefix(40))")

        // 1. Copy to clipboard
        ClipboardManager.shared.paste(item: item)

        // 2. Close window immediately
        removeClickMonitor()
        window?.orderOut(nil)
        onDismiss?()

        // 3. Reactivate the previous app, then paste into it
        let appToActivate = previousApp
        previousApp = nil

        NSLog("FlowClip: reactivating \(appToActivate?.localizedName ?? "nil")")
        appToActivate?.activate(options: .activateIgnoringOtherApps)

        // Give the app time to regain focus, then send Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            NSLog("FlowClip: posting synthetic paste")
            self?.keyboardMonitor?.postSyntheticPaste()
        }

        // Show "Copied" toast as visual feedback
        showCopiedToast()
    }

    private var toastWindow: NSWindow?

    private func showCopiedToast() {
        let label = NSTextField(labelWithString: "Copied")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.sizeToFit()

        let padding: CGFloat = 24
        let width = label.frame.width + padding * 2
        let height: CGFloat = 36

        let toast = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.level = .popUpMenu
        toast.hasShadow = true
        toast.ignoresMouseEvents = true

        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = height / 2
        bg.layer?.masksToBounds = true

        label.frame = NSRect(x: padding, y: (height - label.frame.height) / 2, width: label.frame.width, height: label.frame.height)
        bg.addSubview(label)
        toast.contentView = bg

        if let screen = NSScreen.main {
            let x = screen.frame.midX - width / 2
            let y = screen.frame.midY - 80
            toast.setFrameOrigin(NSPoint(x: x, y: y))
        }

        toast.alphaValue = 0
        toast.orderFrontRegardless()
        toastWindow = toast

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            toast.animator().alphaValue = 1
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                toast.animator().alphaValue = 0
            }, completionHandler: {
                toast.orderOut(nil)
                self?.toastWindow = nil
            })
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
}
