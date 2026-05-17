import SwiftUI

struct DashboardView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PerformanceScoreView(score: monitor.performanceScore)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 4),
                    spacing: 12
                ) {
                    StatCardView(
                        title:    "CPU",
                        value:    String(format: "%.0f%%", monitor.cpuUsage * 100),
                        subtitle: "Processor load",
                        icon:     "cpu",
                        color:    AppColors.brandBlue,
                        history:  monitor.cpuHistory
                    )
                    StatCardView(
                        title:    "RAM",
                        value:    formatBytes(monitor.ram.used),
                        subtitle: "of \(formatBytes(monitor.ram.total)) used",
                        icon:     "memorychip",
                        color:    AppColors.brandPurple,
                        history:  monitor.ramHistory
                    )
                    StatCardView(
                        title:    "GPU",
                        value:    monitor.gpuUsage.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                        subtitle: "Graphics load",
                        icon:     "display",
                        color:    AppColors.success,
                        history:  monitor.gpuHistory
                    )
                    StatCardView(
                        title:    "Disk",
                        value:    String(format: "%.0f%%", monitor.disk.fraction * 100),
                        subtitle: "\(formatBytes(monitor.disk.used)) used",
                        icon:     "internaldrive",
                        color:    AppColors.warning,
                        history:  []
                    )
                }

                HStack(spacing: 12) {
                    TempFanView(thermal: monitor.thermal)
                        .frame(maxWidth: .infinity)
                    BatteryView(battery: monitor.battery)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
