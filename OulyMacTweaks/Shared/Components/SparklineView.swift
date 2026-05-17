import SwiftUI
import Charts

struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        if data.isEmpty {
            Rectangle().fill(Color.clear)
                .frame(height: 32)
        } else {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { i, val in
                    LineMark(
                        x: .value("t", i),
                        y: .value("v", val)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                }
                if let last = data.last {
                    AreaMark(
                        x: .value("t", data.count - 1),
                        yStart: .value("v", 0),
                        yEnd: .value("v", last)
                    )
                    .foregroundStyle(color.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...1)
            .frame(height: 32)
        }
    }
}
