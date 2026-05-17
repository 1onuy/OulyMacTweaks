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

@MainActor
final class OptimizationEngineTests: XCTestCase {

    func test_initialState_isIdle() {
        let engine = makeEngine()
        if case .idle = engine.state { } else {
            XCTFail("Expected idle, got \(engine.state)")
        }
    }

    func test_scan_immediatelyTransitionsToScanning() {
        let engine = makeEngine()
        engine.scan()
        if case .scanning = engine.state { } else {
            XCTFail("Expected scanning after scan()")
        }
    }

    func test_scan_completesWithResults() async throws {
        let engine = makeEngine()
        engine.scan()
        try await Task.sleep(nanoseconds: 200_000_000)
        if case let .results(ram, cache) = engine.state {
            XCTAssertEqual(ram, 100_000_000)
            XCTAssertEqual(cache, 2_000_000)
        } else {
            XCTFail("Expected results, got \(engine.state)")
        }
    }

    func test_optimize_transitionsToOptimizingThenDone() async throws {
        let engine = makeEngine()
        engine.state = .results(ram: 100_000_000, cache: 2_000_000)
        engine.optimize()
        if case .optimizing = engine.state { } else {
            XCTFail("Expected optimizing")
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        if case let .done(ramFreed, cacheFreed) = engine.state {
            XCTAssertEqual(ramFreed, 80_000_000)
            XCTAssertEqual(cacheFreed, 1_800_000)
        } else {
            XCTFail("Expected done, got \(engine.state)")
        }
    }

    func test_reset_returnsToIdle() {
        let engine = makeEngine()
        engine.state = .done(ramFreed: 100, cacheFreed: 200)
        engine.reset()
        if case .idle = engine.state { } else {
            XCTFail("Expected idle after reset()")
        }
    }

    private func makeEngine() -> OptimizationEngine {
        OptimizationEngine(
            ramPurger: MockRAMPurger(purgeable: 100_000_000, freed: 80_000_000),
            cacheCleaner: MockCacheCleaner(scanResult: 2_000_000, cleanResult: 1_800_000)
        )
    }
}
