import XCTest
@testable import OulyMacTweaks

final class RAMPurgerTests: XCTestCase {

    func test_mockRAMPurger_returnsFixedValues() {
        let mock = MockRAMPurger(purgeable: 100_000_000, freed: 80_000_000)
        XCTAssertEqual(mock.estimatePurgeable(), 100_000_000)
        XCTAssertEqual(mock.purge(), 80_000_000)
    }

    func test_mockRAMPurger_zeroValues() {
        let mock = MockRAMPurger(purgeable: 0, freed: 0)
        XCTAssertEqual(mock.estimatePurgeable(), 0)
        XCTAssertEqual(mock.purge(), 0)
    }

    func test_estimatePurgeable_isUInt64() {
        // Verify the return type is non-crashing and within plausible range (< 512 GB)
        let purger = RAMPurger()
        let result = purger.estimatePurgeable()
        XCTAssertLessThan(result, 512 * 1024 * 1024 * 1024)
    }
}
