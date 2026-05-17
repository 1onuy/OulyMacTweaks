import IOKit
import Foundation

final class MockGPUMonitor: GPUMonitoring {
    private let fixedUsage: Double?
    init(usage: Double?) { fixedUsage = usage }
    func currentUsage() -> Double? { fixedUsage }
}

final class GPUMonitor: GPUMonitoring {
    func currentUsage() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        var maxUsage: Double? = nil
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                service, &props, kCFAllocatorDefault, 0
            ) == kIOReturnSuccess else { continue }
            let dict = props!.takeRetainedValue() as NSDictionary
            if let perf = dict["PerformanceStatistics"] as? [String: Any],
               let util = perf["Device Utilization %"] as? Double {
                maxUsage = max(maxUsage ?? 0, util / 100.0)
            }
        }
        return maxUsage
    }
}
