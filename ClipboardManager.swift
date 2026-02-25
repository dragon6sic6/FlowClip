import AppKit
import Combine

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let preview: String
    let timestamp: Date
    let sourceApp: String?
    var isImage: Bool = false
    var image: NSImage?

    init(content: String, sourceApp: String? = nil) {
        self.id = UUID()
        self.content = content
        self.preview = String(content.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        self.timestamp = Date()
        self.sourceApp = sourceApp
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var items: [ClipboardItem] = []
    @Published var sessionDuration: TimeInterval = 1800 // 30 minutes default

    private var lastChangeCount: Int = 0
    private var pollTimer: Timer?
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSettings()
        startPolling()
        startSessionTimer()
    }

    private func loadSettings() {
        let duration = UserDefaults.standard.double(forKey: "sessionDuration")
        if duration > 0 {
            sessionDuration = duration
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(sessionDuration, forKey: "sessionDuration")
    }

    func startPolling() {
        pollTimer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let content = NSPasteboard.general.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Avoid duplicates at the top
        if items.first?.content == content { return }

        // Remove if already exists (move to top)
        items.removeAll { $0.content == content }

        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName
        let newItem = ClipboardItem(content: content, sourceApp: frontApp)

        DispatchQueue.main.async {
            self.items.insert(newItem, at: 0)
        }
    }

    func paste(item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }

    func remove(item: ClipboardItem) {
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == item.id }
        }
    }

    func clearAll() {
        DispatchQueue.main.async {
            self.items.removeAll()
        }
        resetSessionTimer()
    }

    func startSessionTimer() {
        sessionTimer?.invalidate()
        guard sessionDuration > 0 else { return }
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionDuration, repeats: false) { [weak self] _ in
            self?.clearAll()
        }
    }

    func resetSessionTimer() {
        startSessionTimer()
    }

    func updateSessionDuration(_ duration: TimeInterval) {
        sessionDuration = duration
        saveSettings()
        startSessionTimer()
    }
}
