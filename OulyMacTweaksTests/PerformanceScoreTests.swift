import XCTest
@testable import OulyMacTweaks

final class PerformanceScoreTests: XCTestCase {
    let calc = PerformanceScoreCalculator()

    func test_perfectConditions_returns100() {
        let score = calc.score(cpu: 0.0, ram: 0.0, disk: 0.0, cpuTemp: 50)
        XCTAssertEqual(score, 100)
    }

    func test_heavyLoad_returnsLowScore() {
        let score = calc.score(cpu: 0.95, ram: 0.95, disk: 0.95, cpuTemp: 90)
        XCTAssertLessThan(score, 20)
    }

    func test_highTemp_reducesScore() {
        let cool = calc.score(cpu: 0.0, ram: 0.0, disk: 0.0, cpuTemp: 50)
        let hot  = calc.score(cpu: 0.0, ram: 0.0, disk: 0.0, cpuTemp: 90)
        XCTAssertGreaterThan(cool, hot)
    }

    func test_nilTemp_usesMaxTempScore() {
        let withTemp    = calc.score(cpu: 0.0, ram: 0.0, disk: 0.0, cpuTemp: 50)
        let withoutTemp = calc.score(cpu: 0.0, ram: 0.0, disk: 0.0, cpuTemp: nil)
        XCTAssertEqual(withTemp, withoutTemp)
    }

    func test_scoreAlwaysClamped0to100() {
        let s1 = calc.score(cpu: 2.0, ram: 2.0, disk: 2.0, cpuTemp: 200)
        let s2 = calc.score(cpu: -1.0, ram: -1.0, disk: -1.0, cpuTemp: -50)
        XCTAssertGreaterThanOrEqual(s1, 0)
        XCTAssertLessThanOrEqual(s2, 100)
    }
}
