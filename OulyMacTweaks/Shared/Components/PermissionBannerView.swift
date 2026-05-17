import SwiftUI

struct PermissionBannerView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.warning)
            Text(message)
                .font(.footnote)
            Spacer()
            Button("Grant Access", action: action)
                .buttonStyle(.borderedProminent)
                .tint(AppColors.brandBlue)
                .controlSize(.small)
        }
        .padding(12)
        .background(AppColors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
