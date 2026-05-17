import Foundation
import Observation

@Observable
final class OptimizationEngine: @unchecked Sendable {

    // MARK: - State

    enum State {
        case idle
        case scanning
        case results(ram: UInt64, cache: UInt64)
        case optimizing(ram: UInt64, cache: UInt64)
        case done(ramFreed: UInt64, cacheFreed: UInt64)
    }

    var state: State = .idle

    // MARK: - Dependencies

    private let ramPurger: RAMPurging
    private let cacheCleaner: CacheScanning

    init(
        ramPurger: RAMPurging = RAMPurger(),
        cacheCleaner: CacheScanning = CacheCleaner()
    ) {
        self.ramPurger = ramPurger
        self.cacheCleaner = cacheCleaner
    }

    // MARK: - Actions

    @MainActor
    func scan() {
        state = .scanning
        Task {
            async let ram = Task.detached(priority: .utility) {
                self.ramPurger.estimatePurgeable()
            }.value
            async let cache = Task.detached(priority: .utility) {
                self.cacheCleaner.scan()
            }.value
            let (r, c) = await (ram, cache)
            state = .results(ram: r, cache: c)
        }
    }

    @MainActor
    func optimize() {
        guard case let .results(ram, cache) = state else { return }
        state = .optimizing(ram: ram, cache: cache)
        Task {
            async let ramFreed = Task.detached(priority: .utility) {
                self.ramPurger.purge()
            }.value
            async let cacheFreed = Task.detached(priority: .utility) {
                self.cacheCleaner.clean()
            }.value
            let (r, c) = await (ramFreed, cacheFreed)
            UserDefaults.standard.set(Date().timeIntervalSince1970,
                                      forKey: "lastOptimizedDate")
            state = .done(ramFreed: r, cacheFreed: c)
        }
    }

    @MainActor
    func reset() {
        state = .idle
    }
}
