import SwiftUI

struct SettingsView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var selectedDuration: DurationOption = .thirtyMinutes
    @State private var customMinutes: Int = 30

    enum DurationOption: CaseIterable {
        case fifteenMinutes, thirtyMinutes, oneHour, twoHours, untilQuit, custom

        var label: String {
            switch self {
            case .fifteenMinutes: return "15 min"
            case .thirtyMinutes: return "30 min"
            case .oneHour: return "1 hour"
            case .twoHours: return "2 hours"
            case .untilQuit: return "Forever"
            case .custom: return "Custom"
            }
        }

        var seconds: TimeInterval {
            switch self {
            case .fifteenMinutes: return 900
            case .thirtyMinutes: return 1800
            case .oneHour: return 3600
            case .twoHours: return 7200
            case .untilQuit: return 0
            case .custom: return 0
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)

                Text("FlowClip")
                    .font(.system(size: 18, weight: .bold))

                Text("Clipboard Manager")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Content
            ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {

                // Session Duration card
                settingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        cardHeader(icon: "timer", title: "Session Duration")

                        Text("History clears automatically after this time.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)

                        // Duration grid — 3 columns, equal width
                        let columns = [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ]
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(DurationOption.allCases, id: \.self) { option in
                                durationButton(option)
                            }
                        }

                        // Custom stepper
                        if selectedDuration == .custom {
                            customStepper()
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // Clippings card
                settingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        cardHeader(icon: "doc.plaintext", title: "Clippings")

                        // Remember
                        HStack {
                            Text("Remember")
                                .font(.system(size: 12))
                            Spacer()
                            stepperControl(
                                value: Binding(
                                    get: { manager.maxRemember },
                                    set: { manager.maxRemember = $0; manager.saveSettings() }
                                ),
                                range: 5...200,
                                step: 5,
                                label: "\(manager.maxRemember)"
                            )
                        }

                        Divider().opacity(0.3)

                        // Display in menu
                        HStack {
                            Text("Display in menu")
                                .font(.system(size: 12))
                            Spacer()
                            stepperControl(
                                value: Binding(
                                    get: { manager.displayInMenu },
                                    set: { manager.displayInMenu = $0; manager.saveSettings() }
                                ),
                                range: 5...100,
                                step: 5,
                                label: "\(manager.displayInMenu)"
                            )
                        }

                        Divider().opacity(0.3)

                        // Remove duplicates
                        HStack {
                            Text("Remove duplicates")
                                .font(.system(size: 12))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { manager.removeDuplicates },
                                set: { manager.removeDuplicates = $0; manager.saveSettings() }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }
                }

                // Keyboard Shortcuts card
                settingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        cardHeader(icon: "keyboard", title: "Shortcuts")

                        VStack(spacing: 8) {
                            shortcutRow(icon: "doc.on.doc", text: "Copy anything", shortcut: "⌘C")
                            shortcutRow(icon: "list.clipboard", text: "Show picker", shortcut: "Hold ⌘V")
                            shortcutRow(icon: "arrow.up.doc", text: "Paste item", shortcut: "Click")
                            shortcutRow(icon: "escape", text: "Dismiss", shortcut: "Esc")
                        }
                    }
                }

                // Memory card
                settingsCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Items in Memory")
                                .font(.system(size: 12, weight: .medium))
                            Text("\(manager.items.count) item\(manager.items.count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: { manager.clearAll() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                Text("Clear All")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            }

            Spacer(minLength: 8)

            Text("v1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .padding(.bottom, 10)
        }
        .frame(minWidth: 360, minHeight: 420)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            let current = manager.sessionDuration
            if let match = DurationOption.allCases.first(where: { $0.seconds == current && $0 != .custom }) {
                selectedDuration = match
            } else if current == 0 {
                selectedDuration = .untilQuit
            } else {
                selectedDuration = .custom
                customMinutes = Int(current / 60)
            }
        }
    }

    // MARK: - Card Header

    @ViewBuilder
    func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    // MARK: - Duration Button

    @ViewBuilder
    func durationButton(_ option: DurationOption) -> some View {
        let isSelected = selectedDuration == option
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDuration = option
            }
            if option != .custom {
                manager.updateSessionDuration(option.seconds)
            }
        }) {
            Text(option.label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Stepper

    @ViewBuilder
    func customStepper() -> some View {
        HStack(spacing: 8) {
            Text("Duration:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                Button(action: {
                    if customMinutes > 5 { customMinutes -= 5 }
                    manager.updateSessionDuration(TimeInterval(customMinutes * 60))
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Text("\(customMinutes) min")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(width: 56)

                Button(action: {
                    if customMinutes < 480 { customMinutes += 5 }
                    manager.updateSessionDuration(TimeInterval(customMinutes * 60))
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            Spacer()
        }
    }

    // MARK: - Settings Card

    @ViewBuilder
    func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Stepper Control

    @ViewBuilder
    func stepperControl(value: Binding<Int>, range: ClosedRange<Int>, step: Int, label: String) -> some View {
        HStack(spacing: 0) {
            Button(action: {
                let newVal = value.wrappedValue - step
                if newVal >= range.lowerBound { value.wrappedValue = newVal }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: 36)

            Button(action: {
                let newVal = value.wrappedValue + step
                if newVal <= range.upperBound { value.wrappedValue = newVal }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    // MARK: - Shortcut Row

    @ViewBuilder
    func shortcutRow(icon: String, text: String, shortcut: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.75))

            Spacer()

            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
    }
}
