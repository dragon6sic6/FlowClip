import AppKit
import Carbon
import ApplicationServices
import os

class KeyboardMonitor {
    var onShowPicker: (() -> Void)?
    var onHidePicker: (() -> Void)?

    private var clipboardManager: ClipboardManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?

    // Thread-safe state accessed from both the tap thread and main thread
    private var _lock = os_unfair_lock()
    private var _pickerVisible = false
    private var _suppressingV = false
    private var _holdTimer: DispatchWorkItem?

    private(set) var pickerVisible: Bool {
        get { os_unfair_lock_lock(&_lock); defer { os_unfair_lock_unlock(&_lock) }; return _pickerVisible }
        set { os_unfair_lock_lock(&_lock); defer { os_unfair_lock_unlock(&_lock) }; _pickerVisible = newValue }
    }

    private var suppressingV: Bool {
        get { os_unfair_lock_lock(&_lock); defer { os_unfair_lock_unlock(&_lock) }; return _suppressingV }
        set { os_unfair_lock_lock(&_lock); defer { os_unfair_lock_unlock(&_lock) }; _suppressingV = newValue }
    }

    private var holdTimer: DispatchWorkItem? {
        get { os_unfair_lock_lock(&_lock); defer { os_unfair_lock_unlock(&_lock) }; return _holdTimer }
        set { os_unfair_lock_lock(&_lock); defer { os_unfair_lock_unlock(&_lock) }; _holdTimer = newValue }
    }

    private static let holdThreshold: TimeInterval = 0.3
    private static let syntheticMarker: Int64 = 0x464C4F57

    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    func startMonitoring() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            NSLog("MindClip: FAILED to create CGEvent tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Run the event tap on a dedicated background thread so it never
        // blocks on main-thread work (SwiftUI, timers, animations).
        let thread = Thread { [weak self] in
            guard let self, let src = self.runLoopSource else { return }
            self.tapRunLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CFRunLoopRun()
        }
        thread.name = "com.mindclip.eventtap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()

        NSLog("MindClip: CGEvent tap ACTIVE on background thread")
    }

    func stopMonitoring() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let rl = tapRunLoop { CFRunLoopStop(rl) }
        if let rl = tapRunLoop, let src = runLoopSource {
            CFRunLoopRemoveSource(rl, src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        tapRunLoop = nil
        tapThread = nil
    }

    func resetPickerState() {
        pickerVisible = false
        suppressingV = false
        holdTimer?.cancel()
        holdTimer = nil
    }

    func dismissPicker() {
        guard pickerVisible else { return }
        pickerVisible = false
        DispatchQueue.main.async { self.onHidePicker?() }
    }

    func postSyntheticPaste() {
        let src = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags   = .maskCommand
        down.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Event handling (runs on background tap thread)

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if macOS disabled it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Let our own synthetic events through
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch type {
        case .keyDown:
            // Escape dismisses picker
            if keyCode == 53 && pickerVisible {
                DispatchQueue.main.async { self.dismissPicker() }
                return nil
            }

            // Only care about V key
            guard keyCode == 9 else { return Unmanaged.passUnretained(event) }

            // If picker is showing, eat all V presses
            if pickerVisible {
                return nil
            }

            // If we're already suppressing V (repeats, etc), keep suppressing
            if suppressingV {
                return nil
            }

            // Check if Command is held
            let hasCmd = (event.flags.rawValue & CGEventFlags.maskCommand.rawValue) != 0
            guard hasCmd else { return Unmanaged.passUnretained(event) }

            // Cmd+Shift+V = Paste as plain text (strip formatting, don't show picker)
            let hasShift = (event.flags.rawValue & CGEventFlags.maskShift.rawValue) != 0
            if hasShift {
                DispatchQueue.main.async { [weak self] in
                    ClipboardManager.shared.stripFormattingFromClipboard()
                    self?.postSyntheticPaste()
                }
                return nil
            }

            // First Cmd+V detected — suppress it and start hold timer
            suppressingV = true

            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.suppressingV {
                    self.showPickerIfNeeded()
                }
            }
            holdTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdThreshold, execute: work)

            return nil  // SUPPRESS the Cmd+V

        case .keyUp:
            guard keyCode == 9 else { return Unmanaged.passUnretained(event) }

            if suppressingV && !pickerVisible {
                // Quick tap — user released before timer fired
                holdTimer?.cancel()
                holdTimer = nil
                suppressingV = false
                postSyntheticPaste()
                return nil
            }

            // Picker is visible — just clear V state, picker stays open
            if pickerVisible {
                suppressingV = false
                return nil
            }

            // Normal V keyUp (no Cmd was involved)
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func showPickerIfNeeded() {
        guard !pickerVisible else { return }
        guard ClipboardManager.shared.items.count > 0 else {
            suppressingV = false
            postSyntheticPaste()
            return
        }
        pickerVisible = true
        DispatchQueue.main.async { self.onShowPicker?() }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let ptr = userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(ptr).takeUnretainedValue()
    return monitor.handle(proxy: proxy, type: type, event: event)
}
