import SwiftUI

struct BatteryView: View {
    let battery: BatterySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Battery Health", systemImage: "battery.100percent")
                .font(AppFonts.sectionHeader)

            if battery.isPresent {
                HStack(spacing: 24) {
                    stat(label: "Capacity", value: "\(battery.percent)%")
                    stat(label: "Health",   value: String(format: "%.0f%%", battery.health * 100))
                    stat(label: "Cycles",   value: "\(battery.cycleCount)")
                }
                GaugeRingView(value: battery.health, color: healthColor, lineWidth: 6)
                    .frame(width: 44, height: 44)
            } else {
                Text("No battery detected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var healthColor: Color {
        battery.health > 0.8 ? AppColors.success :
        battery.health > 0.6 ? AppColors.warning : AppColors.danger
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFonts.cardLabel).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
    }
}
