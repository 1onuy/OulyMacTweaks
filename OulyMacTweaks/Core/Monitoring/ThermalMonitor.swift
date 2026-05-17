import IOKit

final class MockThermalMonitor: ThermalMonitoring {
    private let snap: ThermalSnapshot
    init(cpuTemp: Double?, gpuTemp: Double?, fanRPM: Int?) {
        snap = ThermalSnapshot(cpuTemp: cpuTemp, gpuTemp: gpuTemp, fanRPM: fanRPM)
    }
    func snapshot() -> ThermalSnapshot { snap }
}

final class ThermalMonitor: ThermalMonitoring {
    func snapshot() -> ThermalSnapshot {
        ThermalSnapshot(
            cpuTemp: readSMCDouble(key: "TC0P"),
            gpuTemp: readSMCDouble(key: "TG0P"),
            fanRPM:  readSMCFan()
        )
    }

    // MARK: - SMC helpers

    private func smcService() -> io_service_t {
        IOServiceGetMatchingService(kIOMainPortDefault,
                                    IOServiceMatching("AppleSMC"))
    }

    private func readSMCDouble(key: String) -> Double? {
        let service = smcService()
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else {
            return nil
        }
        defer { IOServiceClose(conn) }

        var keyInt: UInt32 = 0
        for ch in key.utf8 { keyInt = (keyInt << 8) | UInt32(ch) }

        var input  = SMCKeyData_t()
        var output = SMCKeyData_t()
        input.key = keyInt
        input.data8 = SMC_CMD_READ_KEYINFO

        var inputSize  = MemoryLayout<SMCKeyData_t>.size
        var outputSize = MemoryLayout<SMCKeyData_t>.size

        guard IOConnectCallStructMethod(
            conn, UInt32(KERNEL_INDEX_SMC),
            &input,  inputSize,
            &output, &outputSize
        ) == kIOReturnSuccess else { return nil }

        input.keyInfo = output.keyInfo
        input.data8   = SMC_CMD_READ_BYTES

        guard IOConnectCallStructMethod(
            conn, UInt32(KERNEL_INDEX_SMC),
            &input,  inputSize,
            &output, &outputSize
        ) == kIOReturnSuccess else { return nil }

        let b0 = Double(output.bytes.0)
        let b1 = Double(output.bytes.1)
        let raw = b0 * 256 + b1
        return raw / 256.0
    }

    private func readSMCFan() -> Int? {
        guard let raw = readSMCDouble(key: "F0Ac") else { return nil }
        return Int(raw / 4)
    }
}

// MARK: - SMC constants and structs

private let KERNEL_INDEX_SMC     = 2
private let SMC_CMD_READ_BYTES   = UInt8(5)
private let SMC_CMD_READ_KEYINFO = UInt8(9)

private struct SMCKeyInfo_t {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCKeyData_t {
    var key: UInt32 = 0
    var vers = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
    var pLimitData = (UInt8(0), UInt8(0), UInt8(0))
    var keyInfo = SMCKeyInfo_t()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = (
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0)
    )
}
