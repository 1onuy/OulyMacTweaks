import Darwin
import Foundation

// MARK: - Protocol

protocol RAMPurging {
    func estimatePurgeable() -> UInt64
    func purge() -> UInt64
}

// MARK: - Mock

struct MockRAMPurger: RAMPurging {
    let purgeable: UInt64
    let freed: UInt64
    func estimatePurgeable() -> UInt64 { purgeable }
    func purge() -> UInt64 { freed }
}

// MARK: - Real

struct RAMPurger: RAMPurging {

    /// Returns bytes of inactive RAM the OS can reclaim.
    func estimatePurgeable() -> UInt64 {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(stats.inactive_count) * UInt64(vm_page_size)
    }

    /// Applies memory pressure to force the OS to reclaim inactive pages.
    /// No sudo required — uses vm_allocate in the app's own address space.
    /// Returns the estimated bytes freed (inactive count before purge).
    func purge() -> UInt64 {
        let estimated = estimatePurgeable()
        guard estimated > 0 else { return 0 }

        // Allocate up to 80% of estimated inactive RAM to create pressure
        let targetBytes = vm_size_t(estimated * 4 / 5)
        var address: vm_address_t = 0

        guard vm_allocate(mach_task_self_, &address, targetBytes, VM_FLAGS_ANYWHERE) == KERN_SUCCESS else {
            return 0
        }

        // Touch every page to force physical allocation, compelling OS to compress inactives
        let pageSize = Int(vm_page_size)
        let pageCount = Int(targetBytes) / pageSize
        for i in 0..<pageCount {
            let ptr = UnsafeMutableRawPointer(bitPattern: UInt(address) + UInt(i * pageSize))
            ptr?.storeBytes(of: UInt8(0), as: UInt8.self)
        }

        vm_deallocate(mach_task_self_, address, targetBytes)
        return estimated
    }
}
