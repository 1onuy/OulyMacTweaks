import Foundation
import Observation

@Observable
final class SystemMonitor {
    // Current values
    var cpuUsage: Double = 0
    var ram      = RAMSnapshot(used: 0, total: 1)
    var gpuUsage: Double? = nil
    var thermal  = ThermalSnapshot(cpuTemp: nil, gpuTemp: nil, fanRPM: nil)
    var disk     = DiskSnapshot(used: 0, total: 1)
    var battery  = BatterySnapshot(percent: -1, cycleCount: 0, health: 1.0)

    // History (last 60 samples)
    private(set) var cpuHistory: [Double] = []
    private(set) var ramHistory: [Double] = []
    private(set) var gpuHistory: [Double] = []

    private(set) var performanceScore: Int = 100

    // Internal
    private let cpu:      CPUMonitoring
    private let ramMon:   RAMMonitoring
    private let gpu:      GPUMonitoring
    private let thermalMon: ThermalMonitoring
    private let diskMon:  DiskMonitoring
    private let batMon:   BatteryMonitoring
    private let calc      = PerformanceScoreCalculator()

    private var fastTimer: Timer?
    private var slowTimer: Timer?

    init(
        cpu:     CPUMonitoring     = CPUMonitor(),
        ram:     RAMMonitoring     = RAMMonitor(),
        gpu:     GPUMonitoring     = GPUMonitor(),
        thermal: ThermalMonitoring = ThermalMonitor(),
        disk:    DiskMonitoring    = DiskMonitor(),
        battery: BatteryMonitoring = BatteryMonitor()
    ) {
        self.cpu        = cpu
        self.ramMon     = ram
        self.gpu        = gpu
        self.thermalMon = thermal
        self.diskMon    = disk
        self.batMon     = battery
    }

    func startPolling() {
        _ = cpu.currentUsage()   // prime CPU delta
        scheduleTimers()
        pollFast()
        pollSlow()
    }

    func stopPolling() {
        fastTimer?.invalidate()
        slowTimer?.invalidate()
        fastTimer = nil
        slowTimer = nil
    }

    private func scheduleTimers() {
        fastTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pollFast()
        }
        slowTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.pollSlow()
        }
    }

    private func pollFast() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let cpuVal    = self.cpu.currentUsage()
            let ramSnap   = self.ramMon.snapshot()
            let gpuVal    = self.gpu.currentUsage()
            let thermSnap = self.thermalMon.snapshot()

            DispatchQueue.main.async {
                self.cpuUsage = cpuVal
                self.ram      = ramSnap
                self.gpuUsage = gpuVal
                self.thermal  = thermSnap
                self.appendHistory(cpu: cpuVal, ram: ramSnap.fraction, gpu: gpuVal ?? 0)
                self.recalcScore()
            }
        }
    }

    private func pollSlow() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let diskSnap = self.diskMon.snapshot()
            let batSnap  = self.batMon.snapshot()
            DispatchQueue.main.async {
                self.disk    = diskSnap
                self.battery = batSnap
                self.recalcScore()
            }
        }
    }

    private func appendHistory(cpu: Double, ram: Double, gpu: Double) {
        func append(_ val: Double, to arr: inout [Double]) {
            arr.append(val)
            if arr.count > 60 { arr.removeFirst() }
        }
        append(cpu, to: &cpuHistory)
        append(ram, to: &ramHistory)
        append(gpu, to: &gpuHistory)
    }

    private func recalcScore() {
        performanceScore = calc.score(
            cpu:     cpuUsage,
            ram:     ram.fraction,
            disk:    disk.fraction,
            cpuTemp: thermal.cpuTemp
        )
    }
}
