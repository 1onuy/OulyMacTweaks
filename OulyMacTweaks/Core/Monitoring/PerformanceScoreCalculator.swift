import Foundation

struct PerformanceScoreCalculator {
    private let cpuWeight:  Double = 25
    private let ramWeight:  Double = 30
    private let diskWeight: Double = 25
    private let tempWeight: Double = 20

    func score(cpu: Double, ram: Double, disk: Double, cpuTemp: Double?) -> Int {
        let cpuScore  = (1 - cpu.clamped(to: 0...1))  * cpuWeight
        let ramScore  = (1 - ram.clamped(to: 0...1))  * ramWeight
        let diskScore = (1 - disk.clamped(to: 0...1)) * diskWeight

        let tempScore: Double
        if let t = cpuTemp {
            switch t {
            case ...70: tempScore = tempWeight
            case ...85: tempScore = tempWeight * 0.5
            default:    tempScore = 0
            }
        } else {
            tempScore = tempWeight
        }

        let raw = cpuScore + ramScore + diskScore + tempScore
        return Int(raw.clamped(to: 0...100))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
