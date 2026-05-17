import SwiftUI

struct StatCardView: View {
    let title:     String
    let value:     String
    let subtitle:  String
    let icon:      String
    let color:     Color
    let history:   [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(AppFonts.cardLabel)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(AppFonts.dashboardNumber)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(AppFonts.cardLabel)
                .foregroundStyle(.secondary)
            SparklineView(data: history, color: color)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
