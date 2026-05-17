import IOKit

final class MockBatteryMonitor: BatteryMonitoring {
    private let snap: BatterySnapshot
    init(percent: Int, cycleCount: Int, health: Double) {
        snap = BatterySnapshot(percent: percent, cycleCount: cycleCount, health: health)
    }
    func snapshot() -> BatterySnapshot { snap }
}

final class BatteryMonitor: BatteryMonitoring {
    func snapshot() -> BatterySnapshot {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != 0 else {
            return BatterySnapshot(percent: -1, cycleCount: 0, health: 1.0)
        }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            service, &props, kCFAllocatorDefault, 0
        ) == kIOReturnSuccess else {
            return BatterySnapshot(percent: -1, cycleCount: 0, health: 1.0)
        }
        let dict = props!.takeRetainedValue() as NSDictionary

        let current    = dict["CurrentCapacity"]  as? Int ?? 0
        let maxCap     = dict["MaxCapacity"]       as? Int ?? 100
        let design     = dict["DesignCapacity"]    as? Int ?? maxCap
        let cycleCount = dict["CycleCount"]        as? Int ?? 0

        let percent = maxCap > 0 ? min(100, current * 100 / maxCap) : 0
        let health  = design > 0 ? min(1.0, Double(maxCap) / Double(design)) : 1.0

        return BatterySnapshot(percent: percent, cycleCount: cycleCount, health: health)
    }
}
