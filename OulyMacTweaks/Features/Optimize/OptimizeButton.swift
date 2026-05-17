import SwiftUI

enum OptimizeButtonStyle: Equatable {
    case scan          // blue glow, pulsing
    case optimize      // purple, solid
    case running       // purple, spinner
    case done          // green
    case scanAgain     // blue, no pulse
}

struct OptimizeButton: View {
    let style: OptimizeButtonStyle
    let label: String
    let action: () -> Void

    @State private var glowPulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if style == .running {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                        .tint(.white)
                }
                Text(label)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .shadow(
                        color: backgroundColor.opacity(glowPulse ? 0.7 : 0.35),
                        radius: glowPulse ? 18 : 8,
                        y: 2
                    )
                    .animation(
                        style == .scan
                            ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                            : .default,
                        value: glowPulse
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(style == .running)
        .onAppear { startGlowIfNeeded() }
        .onChange(of: style) { _, _ in
            withAnimation(nil) { glowPulse = false }
            Task { @MainActor in startGlowIfNeeded() }
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .scan, .scanAgain: return AppColors.brandBlue
        case .optimize, .running: return AppColors.brandPurple
        case .done: return AppColors.success
        }
    }

    private func startGlowIfNeeded() {
        guard style == .scan else { return }
        // .scanAgain intentionally excluded — blue but no pulse
        glowPulse = true
    }
}
