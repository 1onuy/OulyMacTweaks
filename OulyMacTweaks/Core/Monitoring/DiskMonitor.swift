import Foundation

final class MockDiskMonitor: DiskMonitoring {
    private let snap: DiskSnapshot
    init(used: UInt64, total: UInt64) { snap = DiskSnapshot(used: used, total: total) }
    func snapshot() -> DiskSnapshot { snap }
}

final class DiskMonitor: DiskMonitoring {
    func snapshot() -> DiskSnapshot {
        let url = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let avail = values.volumeAvailableCapacityForImportantUsage else {
            return DiskSnapshot(used: 0, total: 0)
        }
        let totalBytes = UInt64(total)
        let usedBytes  = totalBytes - UInt64(max(0, avail))
        return DiskSnapshot(used: usedBytes, total: totalBytes)
    }
}
