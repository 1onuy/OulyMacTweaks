import XCTest
@testable import OulyMacTweaks

final class CPUMonitorTests: XCTestCase {

    func test_mockMonitor_returnsConfiguredUsage() {
        let mock = MockCPUMonitor(usage: 0.42)
        XCTAssertEqual(mock.currentUsage(), 0.42, accuracy: 0.001)
    }

    func test_mockMonitor_usageClampedBetweenZeroAndOne() {
        let over = MockCPUMonitor(usage: 1.5)
        let under = MockCPUMonitor(usage: -0.1)
        XCTAssertLessThanOrEqual(over.currentUsage(), 1.0)
        XCTAssertGreaterThanOrEqual(under.currentUsage(), 0.0)
    }

    func test_liveMonitor_returnsValueInValidRange() {
        let monitor = CPUMonitor()
        _ = monitor.currentUsage()
        let usage = monitor.currentUsage()
        XCTAssertGreaterThanOrEqual(usage, 0.0)
        XCTAssertLessThanOrEqual(usage, 1.0)
    }
}
