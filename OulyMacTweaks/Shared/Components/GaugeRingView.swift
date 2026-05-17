import SwiftUI

struct GaugeRingView: View {
    let value: Double      // 0.0–1.0
    let color: Color
    let lineWidth: CGFloat

    init(value: Double, color: Color, lineWidth: CGFloat = 10) {
        self.value = value.clamped(to: 0...1)
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: value)
        }
    }
}
