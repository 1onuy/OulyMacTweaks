import SwiftUI

enum AppColors {
    static let brandBlue    = Color(hex: "2F80ED")
    static let brandPurple  = Color(hex: "7B61FF")
    static let success      = Color(hex: "27AE60")
    static let warning      = Color(hex: "F2994A")
    static let danger       = Color(hex: "EB5757")
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    static func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...100: return AppColors.success
        case 50..<80:  return AppColors.warning
        default:       return AppColors.danger
        }
    }
}

enum AppFonts {
    static let dashboardNumber = Font.largeTitle.weight(.semibold)
    static let sectionHeader   = Font.headline
    static let cardLabel       = Font.footnote
}
