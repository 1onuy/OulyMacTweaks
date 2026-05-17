import SwiftUI

enum ScanResultStatus {
    case pending(bytes: UInt64)
    case active                          // in-progress shimmer state
    case done(freed: UInt64)
    case locked(message: String)
}

struct ScanResultCard: View {
    let icon: String
    let title: String
    let status: ScanResultStatus

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isLocked ? .tertiary : .primary)
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if case .active = status {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(AppColors.brandBlue)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .opacity(isLocked ? 0.4 : 1.0)
    }

    // MARK: - Helpers

    private var isLocked: Bool {
        if case .locked = status { return true }
        return false
    }

    private var iconColor: Color {
        switch status {
        case .pending:  return AppColors.brandBlue
        case .active:   return AppColors.brandBlue
        case .done:     return AppColors.success
        case .locked:   return .secondary
        }
    }

    private var subtitleText: String {
        switch status {
        case .pending(let bytes):   return formatBytes(bytes) + " available"
        case .active:               return "Working…"
        case .done(let freed):      return formatBytes(freed) + " freed"
        case .locked(let msg):      return msg
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 0.1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return "< 1 MB"
    }
}
