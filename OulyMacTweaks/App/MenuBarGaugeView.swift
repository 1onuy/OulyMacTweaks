import AppKit

/// Custom NSView that draws a circular gauge ring + score number for the menu bar status item.
final class MenuBarGaugeView: NSView {

    var score: Int = 100 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 7.5
        let lineWidth: CGFloat = 2.0

        // Background ring
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius,
                         startAngle: 0, endAngle: 360, clockwise: false)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        bgPath.lineWidth = lineWidth
        bgPath.stroke()

        // Foreground arc — starts at top (90°), sweeps clockwise
        let fraction = CGFloat(min(100, max(0, score))) / 100.0
        let endAngle = 90.0 - (fraction * 360.0)
        let fgPath = NSBezierPath()
        fgPath.appendArc(withCenter: center, radius: radius,
                         startAngle: 90, endAngle: endAngle, clockwise: true)
        gaugeColor(for: score).setStroke()
        fgPath.lineWidth = lineWidth
        fgPath.lineCapStyle = .round
        fgPath.stroke()

        // Score number — centered
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: "\(score)", attributes: attrs)
        let sz = str.size()
        str.draw(at: CGPoint(x: center.x - sz.width / 2,
                             y: center.y - sz.height / 2))
    }

    private func gaugeColor(for score: Int) -> NSColor {
        switch score {
        case 80...100: return NSColor(red: 0.153, green: 0.682, blue: 0.376, alpha: 1) // success green
        case 50..<80:  return NSColor(red: 0.949, green: 0.600, blue: 0.290, alpha: 1) // warning amber
        default:       return NSColor(red: 0.922, green: 0.341, blue: 0.341, alpha: 1) // danger red
        }
    }
}
