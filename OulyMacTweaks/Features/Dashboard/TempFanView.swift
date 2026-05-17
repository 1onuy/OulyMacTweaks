import SwiftUI

struct TempFanView: View {
    let thermal: ThermalSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Temperatures", systemImage: "thermometer.medium")
                .font(AppFonts.sectionHeader)

            HStack(spacing: 24) {
                tempItem(label: "CPU", temp: thermal.cpuTemp)
                tempItem(label: "GPU", temp: thermal.gpuTemp)
                if let fan = thermal.fanRPM {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fan").font(AppFonts.cardLabel).foregroundStyle(.secondary)
                        Text("\(fan) RPM").font(.callout.weight(.medium))
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func tempItem(label: String, temp: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFonts.cardLabel).foregroundStyle(.secondary)
            if let t = temp {
                Text(String(format: "%.0f°C", t))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(tempColor(t))
            } else {
                Text("—").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func tempColor(_ t: Double) -> Color {
        t > 85 ? AppColors.danger : t > 70 ? AppColors.warning : AppColors.success
    }
}
