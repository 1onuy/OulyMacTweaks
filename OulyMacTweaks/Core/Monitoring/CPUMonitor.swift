import Darwin

final class MockCPUMonitor: CPUMonitoring {
    private let fixedUsage: Double
    init(usage: Double) { fixedUsage = max(0, min(1, usage)) }
    func currentUsage() -> Double { fixedUsage }
}

final class CPUMonitor: CPUMonitoring {
    private let lock = NSLock()
    private var prevUser:   [Double] = []
    private var prevSystem: [Double] = []
    private var prevIdle:   [Double] = []
    private var prevNice:   [Double] = []

    func currentUsage() -> Double {
        lock.lock()
        defer { lock.unlock() }

        var numCPUs: natural_t = 0
        var cpuInfoPtr: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        guard host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfoPtr, &numCPUInfo
        ) == KERN_SUCCESS, let cpuInfo = cpuInfoPtr else { return 0 }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let count = Int(numCPUs)
        var user   = [Double](repeating: 0, count: count)
        var system = [Double](repeating: 0, count: count)
        var idle   = [Double](repeating: 0, count: count)
        var nice   = [Double](repeating: 0, count: count)

        for i in 0..<count {
            let b = Int(CPU_STATE_MAX) * i
            user[i]   = Double(cpuInfo[b + Int(CPU_STATE_USER)])
            system[i] = Double(cpuInfo[b + Int(CPU_STATE_SYSTEM)])
            idle[i]   = Double(cpuInfo[b + Int(CPU_STATE_IDLE)])
            nice[i]   = Double(cpuInfo[b + Int(CPU_STATE_NICE)])
        }

        var totalUsed = 0.0
        var totalAll  = 0.0

        if prevUser.count == count {
            for i in 0..<count {
                let dUser   = user[i]   - prevUser[i]
                let dSystem = system[i] - prevSystem[i]
                let dIdle   = idle[i]   - prevIdle[i]
                let dNice   = nice[i]   - prevNice[i]
                let used    = dUser + dSystem + dNice
                let all     = used + dIdle
                if all > 0 { totalUsed += used; totalAll += all }
            }
        }

        prevUser = user; prevSystem = system; prevIdle = idle; prevNice = nice
        guard totalAll > 0 else { return 0 }
        return max(0, min(1, totalUsed / totalAll))
    }
}
