import XCTest
@testable import OulyMacTweaks

final class RAMPurgerTests: XCTestCase {

    func test_mockRAMPurger_returnsFixedValues() {
        let mock = MockRAMPurger(purgeable: 100_000_000, freed: 80_000_000)
        XCTAssertEqual(mock.estimatePurgeable(), 100_000_000)
        XCTAssertEqual(mock.purge(), 80_000_000)
    }

    func test_estimatePurgeable_returnsNonNegative() {
        let purger = RAMPurger()
        XCTAssertGreaterThanOrEqual(purger.estimatePurgeable(), 0)
    }

    func test_purge_returnsNonNegative() {
        let purger = RAMPurger()
        XCTAssertGreaterThanOrEqual(purger.purge(), 0)
    }
}
