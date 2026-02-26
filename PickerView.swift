import SwiftUI
import AppKit

struct PickerView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    var onSelect: (ClipboardItem) -> Void
    var onDismiss: () -> Void

    @State private var hoveredId: UUID? = nil
    @State private var appeared = false
    @State private var searchText = ""

    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty { return manager.items }
        return manager.items.filter { $0.preview.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            // Opaque background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("Clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Session timer badge
                    SessionTimerBadge()

                    // Clear all button
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            manager.clearAll()
                        }
                        onDismiss()
                    }) {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Search bar
                if manager.items.count > 3 {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                Divider()
                    .opacity(0.5)

                // Items list
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemRow(
                                item: item,
                                index: index,
                                isHovered: hoveredId == item.id,
                                onSelect: { onSelect(item) },
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        manager.remove(item: item)
                                    }
                                }
                            )
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    hoveredId = hovering ? item.id : nil
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.75)
                                .delay(Double(index) * 0.04),
                                value: appeared
                            )
                        }

                        if filteredItems.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.tertiary)
                                Text("No results")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 24)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }

                // Footer hint
                HStack {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    Text("Click to paste • Hover for actions")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    Spacer()
                    Text("\(manager.items.count) item\(manager.items.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isHovered: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void

    @State private var showDelete = false

    var body: some View {
        HStack(spacing: 10) {
            // Index badge
            ZStack {
                Circle()
                    .fill(index == 0 ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1))
                    .frame(width: 26, height: 26)
                Text(index < 9 ? "\(index + 1)" : "•")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(index == 0 ? Color.accentColor : .secondary)
            }

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary.opacity(isHovered ? 1.0 : 0.85))

                if let source = item.sourceApp {
                    Text(source)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Hover action icons
            if isHovered {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .highPriorityGesture(TapGesture().onEnded { onSelect() })

                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .highPriorityGesture(TapGesture().onEnded { onDelete() })
                }
                .padding(.trailing, 4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered
                    ? (index == 0 ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.07))
                    : Color.clear
                )
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isHovered ? Color.accentColor.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { onSelect() }
    }
}

struct SessionTimerBadge: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var timeLeft: String = ""
    @State private var timer: Timer? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 10))
            Text(timeLeft)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .onAppear {
            updateTime()
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                updateTime()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    func updateTime() {
        let duration = manager.sessionDuration
        if duration >= 3600 {
            timeLeft = "\(Int(duration / 3600))h session"
        } else {
            timeLeft = "\(Int(duration / 60))min session"
        }
    }
}
