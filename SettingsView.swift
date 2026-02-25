import SwiftUI

struct SettingsView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var selectedDuration: DurationOption = .thirtyMinutes
    @State private var customMinutes: Int = 30

    enum DurationOption: String, CaseIterable {
        case fifteenMinutes = "15 minutes"
        case thirtyMinutes = "30 minutes"
        case oneHour = "1 hour"
        case twoHours = "2 hours"
        case untilQuit = "Until quit"
        case custom = "Custom"

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
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FlowClip")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Clipboard Manager")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            .background(.quaternary.opacity(0.5))

            Divider()

            // Settings content
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Session Duration", systemImage: "timer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Clipboard history clears automatically after this time.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Picker("Duration", selection: $selectedDuration) {
                            ForEach(DurationOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedDuration) { newValue in
                            if newValue != .custom {
                                manager.updateSessionDuration(newValue.seconds)
                            }
                        }

                        if selectedDuration == .custom {
                            HStack {
                                Stepper(
                                    value: $customMinutes,
                                    in: 1...480,
                                    step: 5
                                ) {
                                    Text("\(customMinutes) minutes")
                                        .font(.system(size: 13))
                                }
                                .onChange(of: customMinutes) { val in
                                    manager.updateSessionDuration(TimeInterval(val * 60))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)

                Divider().padding(.vertical, 4)

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Usage", systemImage: "keyboard")
                            .font(.system(size: 13, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            shortcutRow(icon: "doc.on.doc", text: "Copy", shortcut: "⌘C")
                            shortcutRow(icon: "list.clipboard", text: "Hold to show picker", shortcut: "⌘V hold")
                            shortcutRow(icon: "arrow.up.doc", text: "Paste selected", shortcut: "Click item")
                            shortcutRow(icon: "xmark.circle", text: "Delete item", shortcut: "Hover → ✕")
                        }
                    }
                }
                .padding(.vertical, 8)

                Divider().padding(.vertical, 4)

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Items in memory")
                                .font(.system(size: 13))
                            Text("\(manager.items.count) clipboard item\(manager.items.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Clear Now") {
                            manager.clearAll()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.red.opacity(0.8))
                    }
                }
                .padding(.vertical, 8)
            }
            .formStyle(.grouped)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 420, height: 360)
        .onAppear {
            // Sync picker to current setting
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

    @ViewBuilder
    func shortcutRow(icon: String, text: String, shortcut: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
        }
    }
}
