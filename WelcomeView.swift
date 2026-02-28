import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Hero
            VStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 4)

                Text("Welcome to MindClip")
                    .font(.system(size: 22, weight: .bold))

                Text("A lightweight clipboard manager for macOS")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 36)
            .padding(.bottom, 28)

            // Steps
            VStack(spacing: 0) {
                stepRow(
                    number: 1,
                    icon: "doc.on.doc",
                    title: "Copy as usual",
                    description: "MindClip quietly saves everything you copy with ⌘C.",
                    isLast: false
                )
                stepRow(
                    number: 2,
                    icon: "hand.tap",
                    title: "Hold ⌘V to pick",
                    description: "Tap ⌘V to paste normally. Hold it to open the picker and choose from your history.",
                    isLast: false
                )
                stepRow(
                    number: 3,
                    icon: "lock.shield",
                    title: "Grant Accessibility",
                    description: "MindClip needs Accessibility permission to detect ⌘V. You'll be prompted next.",
                    isLast: true
                )
            }
            .padding(.horizontal, 28)

            Spacer()

            // Get Started button
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 12)

            Text("by Mindact")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .padding(.bottom, 16)
        }
        .frame(width: 400, height: 520)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Step Row

    @ViewBuilder
    func stepRow(number: Int, icon: String, title: String, description: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Number + connector line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 28)
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
    }
}
