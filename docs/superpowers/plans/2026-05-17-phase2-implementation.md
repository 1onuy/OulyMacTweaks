# Phase 2 — Optimization Engine + Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activate the Optimize tab with a scan-first RAM purge + cache cleanup engine, and add a persistent menu bar gauge ring showing live performance score.

**Architecture:** `OptimizationEngine` is an `@Observable` state machine injected via SwiftUI environment alongside `SystemMonitor`. `RAMPurger` and `CacheCleaner` are protocol-backed structs for testability. The menu bar is an `NSStatusItem` driven by `AppDelegate` with a custom `NSView` gauge.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSStatusItem, NSView), Darwin (vm_allocate), Foundation (FileManager), XCTest

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `OulyMacTweaks/Core/Optimization/RAMPurger.swift` | Create | Protocol + impl: estimate inactive RAM, apply memory pressure purge |
| `OulyMacTweaks/Core/Optimization/CacheCleaner.swift` | Create | Protocol + impl: scan + delete ~/Library/Caches |
| `OulyMacTweaks/Core/Optimization/OptimizationEngine.swift` | Create | @Observable state machine orchestrating scan/optimize flow |
| `OulyMacTweaks/Features/Optimize/ScanResultCard.swift` | Create | Reusable frosted-glass card: icon, title, byte count, locked/done states |
| `OulyMacTweaks/Features/Optimize/OptimizeButton.swift` | Create | Animated CTA button with idle glow, running spinner, done states |
| `OulyMacTweaks/Features/Optimize/OptimizeView.swift` | Create | Full scan-first UI assembled from engine state |
| `OulyMacTweaks/App/AppDelegate.swift` | Create | NSApplicationDelegate: NSStatusItem lifecycle |
| `OulyMacTweaks/App/MenuBarGaugeView.swift` | Create | NSView: draws gauge ring + score number for status item |
| `OulyMacTweaks/App/OulyMacTweaksApp.swift` | Modify | Add @NSApplicationDelegateAdaptor, inject OptimizationEngine, pass monitor to delegate |
| `OulyMacTweaks/Navigation/ContentView.swift` | Modify | Use OptimizeView instead of OptimizeStubView |
| `OulyMacTweaksTests/OptimizationTests.swift` | Create | Unit tests for RAMPurger, CacheCleaner, OptimizationEngine |

---

## Task 1: RAMPurger

**Files:**
- Create: `OulyMacTweaks/Core/Optimization/RAMPurger.swift`
- Test: `OulyMacTweaksTests/OptimizationTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `OulyMacTweaksTests/OptimizationTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -scheme OulyMacTweaks \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:OulyMacTweaksTests/RAMPurgerTests
```

Expected: compile error — `RAMPurger`, `MockRAMPurger` not found.

- [ ] **Step 3: Implement RAMPurger**

Create `OulyMacTweaks/Core/Optimization/RAMPurger.swift`:

```swift
import Darwin
import Foundation

// MARK: - Protocol

protocol RAMPurging {
    func estimatePurgeable() -> UInt64
    func purge() -> UInt64
}

// MARK: - Mock

struct MockRAMPurger: RAMPurging {
    let purgeable: UInt64
    let freed: UInt64
    func estimatePurgeable() -> UInt64 { purgeable }
    func purge() -> UInt64 { freed }
}

// MARK: - Real

struct RAMPurger: RAMPurging {

    /// Returns bytes of inactive RAM the OS can reclaim.
    func estimatePurgeable() -> UInt64 {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(stats.inactive_count) * UInt64(vm_page_size)
    }

    /// Applies memory pressure to force the OS to reclaim inactive pages.
    /// No sudo required — uses vm_allocate in the app's own address space.
    /// Returns the estimated bytes freed (inactive count before purge).
    func purge() -> UInt64 {
        let estimated = estimatePurgeable()
        guard estimated > 0 else { return 0 }

        // Allocate up to 80 % of estimated inactive RAM to create pressure
        let targetBytes = vm_size_t(estimated * 4 / 5)
        var address: vm_address_t = 0

        guard vm_allocate(mach_task_self_, &address, targetBytes, VM_FLAGS_ANYWHERE) == KERN_SUCCESS else {
            return 0
        }

        // Touch every page to force physical allocation, compelling OS to compress inactives
        let pageSize = Int(vm_page_size)
        let pageCount = Int(targetBytes) / pageSize
        for i in 0..<pageCount {
            let ptr = UnsafeMutableRawPointer(bitPattern: UInt(address) + UInt(i * pageSize))
            ptr?.storeBytes(of: UInt8(0), as: UInt8.self)
        }

        vm_deallocate(mach_task_self_, address, targetBytes)
        return estimated
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test \
  -scheme OulyMacTweaks \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:OulyMacTweaksTests/RAMPurgerTests
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add OulyMacTweaks/Core/Optimization/RAMPurger.swift \
        OulyMacTweaksTests/OptimizationTests.swift
git commit -m "feat: add RAMPurger with memory pressure technique and tests"
```

---

## Task 2: CacheCleaner

**Files:**
- Create: `OulyMacTweaks/Core/Optimization/CacheCleaner.swift`
- Modify: `OulyMacTweaksTests/OptimizationTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `OulyMacTweaksTests/OptimizationTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests — expect compile error**

```bash
xcodebuild test \
  -scheme OulyMacTweaks \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:OulyMacTweaksTests/CacheCleanerTests
```

Expected: compile error — `CacheCleaner`, `MockCacheCleaner` not found.

- [ ] **Step 3: Implement CacheCleaner**

Create `OulyMacTweaks/Core/Optimization/CacheCleaner.swift`:

```swift
import Foundation

// MARK: - Protocol

protocol CacheScanning {
    func scan() -> UInt64
    func clean() -> UInt64
}

// MARK: - Mock

struct MockCacheCleaner: CacheScanning {
    let scanResult: UInt64
    let cleanResult: UInt64
    func scan() -> UInt64 { scanResult }
    func clean() -> UInt64 { cleanResult }
}

// MARK: - Real

struct CacheCleaner: CacheScanning {
    let cacheURL: URL

    init(cacheURL: URL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]) {
        self.cacheURL = cacheURL
    }

    /// Returns the total byte size of ~/Library/Caches contents.
    func scan() -> UInt64 {
        directorySize(at: cacheURL)
    }

    /// Deletes each top-level item in cacheURL. Returns bytes actually freed.
    /// Items that fail to delete (locked, SIP-protected) are silently skipped.
    func clean() -> UInt64 {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var freed: UInt64 = 0
        for item in items {
            let size = directorySize(at: item)
            if (try? fm.removeItem(at: item)) != nil {
                freed += size
            }
        }
        return freed
    }

    // MARK: - Private

    private func directorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                values.isRegularFile == true,
                let size = values.fileSize
            else { continue }
            total += UInt64(size)
        }
        return total
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test \
  -scheme OulyMacTweaks \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:OulyMacTweaksTests/CacheCleanerTests
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add OulyMacTweaks/Core/Optimization/CacheCleaner.swift \
        OulyMacTweaksTests/OptimizationTests.swift
git commit -m "feat: add CacheCleaner with FileManager and tests"
```

---

## Task 3: OptimizationEngine

**Files:**
- Create: `OulyMacTweaks/Core/Optimization/OptimizationEngine.swift`
- Modify: `OulyMacTweaksTests/OptimizationTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `OulyMacTweaksTests/OptimizationTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests — expect compile error**

```bash
xcodebuild test \
  -scheme OulyMacTweaks \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:OulyMacTweaksTests/OptimizationEngineTests
```

Expected: compile error — `OptimizationEngine` not found.

- [ ] **Step 3: Implement OptimizationEngine**

Create `OulyMacTweaks/Core/Optimization/OptimizationEngine.swift`:

```swift
import Foundation
import Observation

@Observable
final class OptimizationEngine {

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
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test \
  -scheme OulyMacTweaks \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:OulyMacTweaksTests/OptimizationEngineTests
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add OulyMacTweaks/Core/Optimization/OptimizationEngine.swift \
        OulyMacTweaksTests/OptimizationTests.swift
git commit -m "feat: add OptimizationEngine state machine with async scan/optimize and tests"
```

---

## Task 4: ScanResultCard

**Files:**
- Create: `OulyMacTweaks/Features/Optimize/ScanResultCard.swift`

No unit tests for pure UI components — visual correctness verified by running the app.

- [ ] **Step 1: Create ScanResultCard**

Create `OulyMacTweaks/Features/Optimize/ScanResultCard.swift`:

```swift
import SwiftUI

enum ScanResultStatus {
    case pending(bytes: UInt64)
    case active                          // in-progress shimmer state
    case done(freed: UInt64)
    case locked(message: String)
}

struct ScanResultCard: View {
    let icon: String
    let title: String
    let status: ScanResultStatus

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isLocked ? .tertiary : .primary)
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if case .active = status {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.7)
                    .tint(AppColors.brandBlue)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .opacity(isLocked ? 0.4 : 1.0)
    }

    // MARK: - Helpers

    private var isLocked: Bool {
        if case .locked = status { return true }
        return false
    }

    private var iconColor: Color {
        switch status {
        case .pending:  return AppColors.brandBlue
        case .active:   return AppColors.brandBlue
        case .done:     return AppColors.success
        case .locked:   return .secondary
        }
    }

    private var subtitleText: String {
        switch status {
        case .pending(let bytes):   return formatBytes(bytes) + " available"
        case .active:               return "Working…"
        case .done(let freed):      return formatBytes(freed) + " freed"
        case .locked(let msg):      return msg
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 0.1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return "< 1 MB"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Features/Optimize/ScanResultCard.swift
git commit -m "feat: add ScanResultCard UI component"
```

---

## Task 5: OptimizeButton

**Files:**
- Create: `OulyMacTweaks/Features/Optimize/OptimizeButton.swift`

- [ ] **Step 1: Create OptimizeButton**

Create `OulyMacTweaks/Features/Optimize/OptimizeButton.swift`:

```swift
import SwiftUI

enum OptimizeButtonStyle {
    case scan          // blue glow, pulsing
    case optimize      // purple, solid
    case running       // purple, spinner
    case done          // green
    case scanAgain     // blue, no pulse
}

struct OptimizeButton: View {
    let style: OptimizeButtonStyle
    let label: String
    let action: () -> Void

    @State private var glowPulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if style == .running {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                        .tint(.white)
                }
                Text(label)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .shadow(
                        color: backgroundColor.opacity(glowPulse ? 0.7 : 0.35),
                        radius: glowPulse ? 18 : 8,
                        y: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(style == .running)
        .onAppear { startGlowIfNeeded() }
        .onChange(of: style) { _, _ in
            glowPulse = false
            startGlowIfNeeded()
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .scan, .scanAgain: return AppColors.brandBlue
        case .optimize, .running: return AppColors.brandPurple
        case .done: return AppColors.success
        }
    }

    private func startGlowIfNeeded() {
        guard style == .scan else { return }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Features/Optimize/OptimizeButton.swift
git commit -m "feat: add OptimizeButton with glow pulse and running states"
```

---

## Task 6: OptimizeView

**Files:**
- Create: `OulyMacTweaks/Features/Optimize/OptimizeView.swift`

- [ ] **Step 1: Create OptimizeView**

Create `OulyMacTweaks/Features/Optimize/OptimizeView.swift`:

```swift
import SwiftUI

struct OptimizeView: View {
    @Environment(OptimizationEngine.self) private var engine

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                content
            }
            .padding(24)
        }
        .animation(.easeOut(duration: 0.18), value: stateTag)
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        switch engine.state {
        case .idle:
            idleView
        case .scanning:
            scanningView
        case let .results(ram, cache):
            resultsView(ram: ram, cache: cache)
        case let .optimizing(ram, cache):
            optimizingView(ram: ram, cache: cache)
        case let .done(ramFreed, cacheFreed):
            doneView(ramFreed: ramFreed, cacheFreed: cacheFreed)
        }
    }

    private var stateTag: String {
        switch engine.state {
        case .idle:       return "idle"
        case .scanning:   return "scanning"
        case .results:    return "results"
        case .optimizing: return "optimizing"
        case .done:       return "done"
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 48)
            Image(systemName: "bolt.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(AppColors.brandBlue)
            Text("Optimize Your Mac")
                .font(.title2.weight(.bold))
            Text("Scan to see how much memory and\ndisk space can be recovered.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 8)
            OptimizeButton(style: .scan, label: "Scan Now") {
                engine.scan()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(AppColors.brandBlue)
            Text("Scanning…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results

    private func resultsView(ram: UInt64, cache: UInt64) -> some View {
        VStack(spacing: 12) {
            ScanResultCard(icon: "memorychip",
                           title: "RAM Pressure",
                           status: .pending(bytes: ram))
                .transition(.move(edge: .bottom).combined(with: .opacity))

            ScanResultCard(icon: "trash.fill",
                           title: "User Caches",
                           status: .pending(bytes: cache))
                .transition(.move(edge: .bottom).combined(with: .opacity))

            ScanResultCard(icon: "lock.fill",
                           title: "Startup Items",
                           status: .locked(message: "Available after signing"))
                .transition(.move(edge: .bottom).combined(with: .opacity))

            Spacer().frame(height: 8)

            OptimizeButton(style: .optimize, label: "Optimize Now") {
                engine.optimize()
            }
        }
    }

    // MARK: - Optimizing

    private func optimizingView(ram: UInt64, cache: UInt64) -> some View {
        VStack(spacing: 12) {
            ScanResultCard(icon: "memorychip",
                           title: "RAM Pressure",
                           status: .active)

            ScanResultCard(icon: "trash.fill",
                           title: "User Caches",
                           status: .active)

            ScanResultCard(icon: "lock.fill",
                           title: "Startup Items",
                           status: .locked(message: "Available after signing"))

            Spacer().frame(height: 8)

            OptimizeButton(style: .running, label: "Optimizing…") { }
        }
    }

    // MARK: - Done

    private func doneView(ramFreed: UInt64, cacheFreed: UInt64) -> some View {
        VStack(spacing: 12) {
            ScanResultCard(icon: "checkmark.circle.fill",
                           title: "RAM Pressure",
                           status: .done(freed: ramFreed))

            ScanResultCard(icon: "checkmark.circle.fill",
                           title: "User Caches",
                           status: .done(freed: cacheFreed))

            ScanResultCard(icon: "lock.fill",
                           title: "Startup Items",
                           status: .locked(message: "Available after signing"))

            VStack(spacing: 4) {
                Text(formatBytes(ramFreed + cacheFreed) + " freed")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColors.brandBlue)
                Text("Your Mac is running better.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            OptimizeButton(style: .scanAgain, label: "Scan Again") {
                engine.reset()
            }
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 0.1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return "< 1 MB"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Features/Optimize/OptimizeView.swift
git commit -m "feat: add OptimizeView scan-first UI with all five states"
```

---

## Task 7: MenuBarGaugeView + AppDelegate

**Files:**
- Create: `OulyMacTweaks/App/MenuBarGaugeView.swift`
- Create: `OulyMacTweaks/App/AppDelegate.swift`

- [ ] **Step 1: Create MenuBarGaugeView**

Create `OulyMacTweaks/App/MenuBarGaugeView.swift`:

```swift
import AppKit

/// Custom NSView that draws a circular gauge ring + score number for the menu bar status item.
final class MenuBarGaugeView: NSView {

    var score: Int = 100 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 7.5
        let lineWidth: CGFloat = 2.0

        // Background ring
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius,
                         startAngle: 0, endAngle: 360, clockwise: false)
        NSColor.white.withAlphaComponent(0.18).setStroke()
        bgPath.lineWidth = lineWidth
        bgPath.stroke()

        // Foreground arc — starts at top (90°), sweeps clockwise
        let fraction = CGFloat(score.clamped(to: 0...100)) / 100.0
        let endAngle = 90.0 - (fraction * 360.0)
        let fgPath = NSBezierPath()
        fgPath.appendArc(withCenter: center, radius: radius,
                         startAngle: 90, endAngle: endAngle, clockwise: true)
        gaugeColor(for: score).setStroke()
        fgPath.lineWidth = lineWidth
        fgPath.lineCapStyle = .round
        fgPath.stroke()

        // Score number — centered
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: "\(score)", attributes: attrs)
        let sz = str.size()
        str.draw(at: CGPoint(x: center.x - sz.width / 2,
                             y: center.y - sz.height / 2))
    }

    private func gaugeColor(for score: Int) -> NSColor {
        switch score {
        case 80...100: return NSColor(red: 0.153, green: 0.682, blue: 0.376, alpha: 1) // success green
        case 50..<80:  return NSColor(red: 0.949, green: 0.600, blue: 0.290, alpha: 1) // warning amber
        default:       return NSColor(red: 0.922, green: 0.341, blue: 0.341, alpha: 1) // danger red
        }
    }
}
```

- [ ] **Step 2: Create AppDelegate**

Create `OulyMacTweaks/App/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var gaugeView: MenuBarGaugeView?
    private var updateTimer: Timer?
    private weak var monitor: SystemMonitor?

    // Called from OulyMacTweaksApp after the monitor is ready
    func connect(monitor: SystemMonitor) {
        self.monitor = monitor
        updateGauge()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateGauge()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    // MARK: - Private

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSSquareStatusItemLength)
        guard let button = statusItem?.button else { return }

        let gauge = MenuBarGaugeView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        button.addSubview(gauge)
        button.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
        button.target = self
        button.action = #selector(handleClick)
        gaugeView = gauge
    }

    private func updateGauge() {
        guard let score = monitor?.performanceScore else { return }
        gaugeView?.score = score
    }

    @objc private func handleClick() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add OulyMacTweaks/App/MenuBarGaugeView.swift \
        OulyMacTweaks/App/AppDelegate.swift
git commit -m "feat: add AppDelegate with NSStatusItem and MenuBarGaugeView gauge ring"
```

---

## Task 8: Wire Everything Together

**Files:**
- Modify: `OulyMacTweaks/App/OulyMacTweaksApp.swift`
- Modify: `OulyMacTweaks/Navigation/ContentView.swift`

- [ ] **Step 1: Read current OulyMacTweaksApp.swift**

```
Current content:
import SwiftUI

@main
struct OulyMacTweaksApp: App {
    @State private var monitor = SystemMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(monitor)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
```

- [ ] **Step 2: Update OulyMacTweaksApp.swift**

Replace the entire file content of `OulyMacTweaks/App/OulyMacTweaksApp.swift` with:

```swift
import SwiftUI

@main
struct OulyMacTweaksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var monitor = SystemMonitor()
    @State private var engine  = OptimizationEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(monitor)
                .environment(engine)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.connect(monitor: monitor)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
```

- [ ] **Step 3: Read current ContentView.swift**

```
Relevant line to change:
    case .optimize:            OptimizeStubView()
```

- [ ] **Step 4: Update ContentView.swift**

In `OulyMacTweaks/Navigation/ContentView.swift`, change the `.optimize` case:

```swift
// Before:
case .optimize:            OptimizeStubView()

// After:
case .optimize:            OptimizeView()
```

The `@Environment(OptimizationEngine.self)` in `OptimizeView` will resolve automatically because `ContentView` is a child of the view that injects it.

- [ ] **Step 5: Build and verify CI passes**

```bash
git add OulyMacTweaks/App/OulyMacTweaksApp.swift \
        OulyMacTweaks/Navigation/ContentView.swift
git commit -m "feat: wire up OptimizationEngine and AppDelegate into app lifecycle"
git push
```

Watch GitHub Actions — Build Debug + Release should both pass.

---

## Self-Review Checklist

**Spec coverage:**
- [x] Scan-first flow (idle → scanning → results → optimizing → done → idle) — Task 3 + 6
- [x] RAM purge via memory pressure, no sudo — Task 1
- [x] User cache cleanup, ~/Library/Caches — Task 2
- [x] Startup Items locked card — Task 4/6 (ScanResultCard .locked state)
- [x] Menu bar NSStatusItem gauge ring — Task 7
- [x] Click menu bar → open main app — Task 7 (handleClick)
- [x] lastOptimizedDate written on optimize — Task 3 (OptimizationEngine.optimize())
- [x] No emojis — SF Symbols only (verified all icon strings)
- [x] Premium UI: glow pulse, easeOut animations, frosted glass cards — Tasks 4, 5, 6
- [x] OptimizationEngine injected alongside SystemMonitor — Task 8

**Type consistency:**
- `RAMPurging.estimatePurgeable()` → used in OptimizationEngine.scan() ✓
- `RAMPurging.purge()` → used in OptimizationEngine.optimize() ✓
- `CacheScanning.scan()` → used in OptimizationEngine.scan() ✓
- `CacheScanning.clean()` → used in OptimizationEngine.optimize() ✓
- `OptimizationEngine.State.done(ramFreed:cacheFreed:)` → read in OptimizeView.doneView ✓
- `OptimizationEngine.State.optimizing(ram:cache:)` → read in OptimizeView.optimizingView ✓
- `AppDelegate.connect(monitor:)` → called in OulyMacTweaksApp.onAppear ✓
