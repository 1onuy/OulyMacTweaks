import SwiftUI

struct PerformanceScoreView: View {
    let score: Int
    @AppStorage("lastOptimizedDate") private var lastOptimizedDate: Double = 0

    private var color: Color { .scoreColor(for: score) }

    private var subtitle: String {
        switch score {
        case 80...100: return "Great shape"
        case 50..<80:  return "Could be better"
        default:       return "Needs attention"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Performance Score")
                    .font(AppFonts.sectionHeader)
                Spacer()
                if lastOptimizedDate > 0 {
                    Text("Last optimized: \(Date(timeIntervalSince1970: lastOptimizedDate).formatted(.relative(presentation: .named)))")
                        .font(AppFonts.cardLabel)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            ZStack {
                GaugeRingView(value: Double(score) / 100, color: color, lineWidth: 14)
                    .frame(width: 120, height: 120)
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
