import XCTest
@testable import OulyMacTweaks

final class DiskMonitorTests: XCTestCase {

    func test_mockSnapshot_returnsConfiguredValues() {
        let mock = MockDiskMonitor(used: 100_000_000_000, total: 500_000_000_000)
        let snap = mock.snapshot()
        XCTAssertEqual(snap.used,  100_000_000_000)
        XCTAssertEqual(snap.total, 500_000_000_000)
    }

    func test_mockSnapshot_fraction() {
        let mock = MockDiskMonitor(used: 250_000_000_000, total: 500_000_000_000)
        XCTAssertEqual(mock.snapshot().fraction, 0.5, accuracy: 0.001)
    }

    func test_liveSnapshot_valuesArePositive() {
        let monitor = DiskMonitor()
        let snap = monitor.snapshot()
        XCTAssertGreaterThan(snap.total, 0)
        XCTAssertGreaterThan(snap.used,  0)
    }

    func test_liveSnapshot_usedBelowTotal() {
        let monitor = DiskMonitor()
        let snap = monitor.snapshot()
        XCTAssertLessThanOrEqual(snap.used, snap.total)
    }
}
