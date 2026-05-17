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

final class CacheCleanerTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_mockCacheCleaner_returnsFixedValues() {
        let mock = MockCacheCleaner(scanResult: 2_000_000, cleanResult: 1_800_000)
        XCTAssertEqual(mock.scan(), 2_000_000)
        XCTAssertEqual(mock.clean(), 1_800_000)
    }

    func test_scan_emptyDirectory_returnsZero() {
        let cleaner = CacheCleaner(cacheURL: tempDir)
        XCTAssertEqual(cleaner.scan(), 0)
    }

    func test_scan_reportsFileSize() throws {
        let file = tempDir.appendingPathComponent("a.cache")
        try Data(repeating: 0xAB, count: 4096).write(to: file)
        let cleaner = CacheCleaner(cacheURL: tempDir)
        XCTAssertGreaterThanOrEqual(cleaner.scan(), 4096)
    }

    func test_clean_deletesContentsReturnsFreed() throws {
        let file = tempDir.appendingPathComponent("b.cache")
        try Data(repeating: 0xCD, count: 4096).write(to: file)
        let cleaner = CacheCleaner(cacheURL: tempDir)
        let freed = cleaner.clean()
        XCTAssertGreaterThan(freed, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func test_clean_doesNotDeleteCacheDirectory_itself() throws {
        let cleaner = CacheCleaner(cacheURL: tempDir)
        _ = cleaner.clean()
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
    }
}
