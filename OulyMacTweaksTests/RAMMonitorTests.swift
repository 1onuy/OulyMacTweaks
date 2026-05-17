import XCTest
@testable import OulyMacTweaks

final class RAMMonitorTests: XCTestCase {

    func test_mockSnapshot_returnsSameValues() {
        let mock = MockRAMMonitor(used: 4_000_000_000, total: 8_000_000_000)
        let snap = mock.snapshot()
        XCTAssertEqual(snap.used,  4_000_000_000)
        XCTAssertEqual(snap.total, 8_000_000_000)
    }

    func test_mockSnapshot_fraction() {
        let mock = MockRAMMonitor(used: 2_000_000_000, total: 8_000_000_000)
        XCTAssertEqual(mock.snapshot().fraction, 0.25, accuracy: 0.001)
    }

    func test_liveSnapshot_totalMatchesPhysicalMemory() {
        let monitor = RAMMonitor()
        let snap = monitor.snapshot()
        let physical = ProcessInfo.processInfo.physicalMemory
        XCTAssertEqual(snap.total, physical)
    }

    func test_liveSnapshot_usedIsPositiveAndBelowTotal() {
        let monitor = RAMMonitor()
        let snap = monitor.snapshot()
        XCTAssertGreaterThan(snap.used, 0)
        XCTAssertLessThanOrEqual(snap.used, snap.total)
    }
}
