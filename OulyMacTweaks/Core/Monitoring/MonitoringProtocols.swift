import Foundation

protocol CPUMonitoring {
    func currentUsage() -> Double     // 0.0–1.0
}

struct RAMSnapshot {
    let used: UInt64    // bytes
    let total: UInt64   // bytes
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

protocol RAMMonitoring {
    func snapshot() -> RAMSnapshot
}

protocol GPUMonitoring {
    func currentUsage() -> Double?    // 0.0–1.0, nil if unavailable
}

struct ThermalSnapshot {
    let cpuTemp: Double?   // °C, nil on Apple Silicon or if unavailable
    let gpuTemp: Double?   // °C
    let fanRPM: Int?       // nil on fanless Macs
}

protocol ThermalMonitoring {
    func snapshot() -> ThermalSnapshot
}

struct DiskSnapshot {
    let used: UInt64    // bytes
    let total: UInt64   // bytes
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

protocol DiskMonitoring {
    func snapshot() -> DiskSnapshot
}

struct BatterySnapshot {
    let percent: Int        // 0–100; -1 if no battery (desktop Mac)
    let cycleCount: Int
    let health: Double      // 0.0–1.0; 1.0 if unavailable
    var isPresent: Bool { percent >= 0 }
}

protocol BatteryMonitoring {
    func snapshot() -> BatterySnapshot
}
