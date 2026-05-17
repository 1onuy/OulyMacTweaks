import Darwin

final class MockRAMMonitor: RAMMonitoring {
    private let snap: RAMSnapshot
    init(used: UInt64, total: UInt64) { snap = RAMSnapshot(used: used, total: total) }
    func snapshot() -> RAMSnapshot { snap }
}

final class RAMMonitor: RAMMonitoring {
    func snapshot() -> RAMSnapshot {
        let total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return RAMSnapshot(used: 0, total: total)
        }

        let page   = UInt64(vm_page_size)
        let active = UInt64(stats.active_count)     * page
        let wired  = UInt64(stats.wire_count)        * page
        let compr  = UInt64(stats.compressor_page_count) * page
        let used   = min(active + wired + compr, total)

        return RAMSnapshot(used: used, total: total)
    }
}
