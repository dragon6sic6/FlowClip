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
    var thumbnail: NSImage?
    var imageSize: NSSize?

    init(content: String, sourceApp: String? = nil) {
        self.id = UUID()
        self.content = content
        self.preview = String(content.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        self.timestamp = Date()
        self.sourceApp = sourceApp
    }

    init(image: NSImage, sourceApp: String? = nil) {
        self.id = UUID()
        self.isImage = true
        self.image = image
        self.imageSize = image.size
        self.content = ""
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        self.preview = "Image — \(w) × \(h)"
        self.timestamp = Date()
        self.sourceApp = sourceApp

        // Generate thumbnail (max 120pt on longest side)
        let maxThumb: CGFloat = 120
        let scale = min(maxThumb / image.size.width, maxThumb / image.size.height, 1.0)
        let thumbSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumb = NSImage(size: thumbSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        self.thumbnail = thumb
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var items: [ClipboardItem] = []
    @Published var sessionDuration: TimeInterval = 1800 // 30 minutes default
    @Published var maxRemember: Int = 50
    @Published var displayInMenu: Int = 20
    @Published var removeDuplicates: Bool = true

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
        let defaults = UserDefaults.standard
        let duration = defaults.double(forKey: "sessionDuration")
        if duration > 0 { sessionDuration = duration }

        let remember = defaults.integer(forKey: "maxRemember")
        if remember > 0 { maxRemember = remember }

        let display = defaults.integer(forKey: "displayInMenu")
        if display > 0 { displayInMenu = display }

        if defaults.object(forKey: "removeDuplicates") != nil {
            removeDuplicates = defaults.bool(forKey: "removeDuplicates")
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(sessionDuration, forKey: "sessionDuration")
        defaults.set(maxRemember, forKey: "maxRemember")
        defaults.set(displayInMenu, forKey: "displayInMenu")
        defaults.set(removeDuplicates, forKey: "removeDuplicates")
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

        let pb = NSPasteboard.general
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName

        // Check for image first (tiff is the universal pasteboard image type on macOS)
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        let hasImage = imageTypes.contains(where: { pb.data(forType: $0) != nil })

        if hasImage, let imgData = pb.data(forType: .tiff) ?? pb.data(forType: .png),
           let image = NSImage(data: imgData) {
            let newItem = ClipboardItem(image: image, sourceApp: frontApp)
            DispatchQueue.main.async {
                // Skip if the top item is already an image of the same size
                if let top = self.items.first, top.isImage,
                   top.imageSize == image.size { return }

                self.items.insert(newItem, at: 0)

                if self.items.count > self.maxRemember {
                    self.items = Array(self.items.prefix(self.maxRemember))
                }
            }
            return
        }

        // Text content
        guard let content = pb.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let newItem = ClipboardItem(content: content, sourceApp: frontApp)

        DispatchQueue.main.async {
            // Avoid duplicates at the top
            if self.items.first?.content == content { return }

            // Remove duplicates if enabled (move to top)
            if self.removeDuplicates {
                self.items.removeAll { $0.content == content && !$0.isImage }
            }

            self.items.insert(newItem, at: 0)

            // Trim to max remember limit
            if self.items.count > self.maxRemember {
                self.items = Array(self.items.prefix(self.maxRemember))
            }
        }
    }

    func paste(item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        if item.isImage, let image = item.image {
            NSPasteboard.general.writeObjects([image])
        } else {
            NSPasteboard.general.setString(item.content, forType: .string)
        }
        // Update changeCount so the poll doesn't re-add this item
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func stripFormattingFromClipboard() {
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string) else { return }
        pb.clearContents()
        pb.setString(text, forType: .string)
        lastChangeCount = pb.changeCount
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
