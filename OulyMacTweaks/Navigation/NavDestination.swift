import Foundation

enum NavDestination: String, CaseIterable, Hashable {
    case dashboard       = "Dashboard"
    case optimize        = "Optimize"
    case gaming          = "Gaming Mode"
    case softwareManager = "Software Manager"
    case aiAdvisor       = "AI Advisor"
    case settings        = "Settings"

    var icon: String {
        switch self {
        case .dashboard:       return "gauge.with.dots.needle.bottom.50percent"
        case .optimize:        return "bolt.fill"
        case .gaming:          return "gamecontroller.fill"
        case .softwareManager: return "tray.full.fill"
        case .aiAdvisor:       return "brain.head.profile"
        case .settings:        return "gear"
        }
    }
}
