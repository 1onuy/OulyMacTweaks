import SwiftUI

struct StubView: View {
    let title: String
    let icon: String
    let phase: Int?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppColors.brandBlue)
            Text(title)
                .font(.title2.weight(.semibold))
            if let p = phase {
                Text("Coming in Phase \(p)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
