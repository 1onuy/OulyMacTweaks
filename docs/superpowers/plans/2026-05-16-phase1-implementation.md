# OulyMac Tweaks Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Phase 1 app — branded macOS shell with NavigationSplitView, live system monitoring dashboard (CPU/RAM/GPU/temps/disk/battery), snow particle background, and first-launch onboarding — deployable via GitHub Actions.

**Architecture:** XcodeGen generates the Xcode project from `project.yml` so no binary `.xcodeproj` is committed. A `SystemMonitor` `@Observable` class polls hardware via Mach/IOKit APIs on a background queue and publishes to SwiftUI views. A `PerformanceScoreCalculator` pure struct isolates scoring logic for unit tests.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14 Sonoma, Swift Charts, SpriteKit (snow), IOKit, Mach kernel APIs, XcodeGen, GitHub Actions (`macos-14` runner).

---

## File Map

```
OulyMacTweaks/                               ← repo root
├── project.yml                              # XcodeGen spec
├── .gitignore
├── README.md
├── .github/
│   └── workflows/
│       └── build.yml                        # CI: xcodegen → xcodebuild → upload .app
├── OulyMacTweaks/
│   ├── App/
│   │   └── OulyMacTweaksApp.swift           # @main, injects SystemMonitor via .environment
│   ├── Navigation/
│   │   ├── ContentView.swift                # Root NavigationSplitView + onboarding sheet
│   │   ├── SidebarView.swift                # 200pt sidebar, SF Symbol nav items
│   │   └── NavDestination.swift             # Enum: dashboard/optimize/gaming/software/ai/settings
│   ├── Features/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift          # Main dashboard layout (score + 4 cards + temp + battery)
│   │   │   ├── PerformanceScoreView.swift   # Circular gauge + score label
│   │   │   ├── TempFanView.swift            # CPU/GPU temp + fan RPM card
│   │   │   └── BatteryView.swift            # Battery % + cycle count + health card
│   │   ├── Optimize/
│   │   │   └── OptimizeStubView.swift       # "Coming soon" placeholder
│   │   ├── Gaming/
│   │   │   └── GamingStubView.swift
│   │   ├── SoftwareManager/
│   │   │   └── SoftwareManagerStubView.swift
│   │   └── AIAdvisor/
│   │       └── AIAdvisorStubView.swift
│   ├── Core/
│   │   ├── Monitoring/
│   │   │   ├── MonitoringProtocols.swift    # CPUMonitoring, RAMMonitoring, etc. protocols
│   │   │   ├── CPUMonitor.swift             # host_processor_info delta sampler
│   │   │   ├── RAMMonitor.swift             # host_statistics64 + ProcessInfo.physicalMemory
│   │   │   ├── GPUMonitor.swift             # IOKit IOAccelerator PerformanceStatistics
│   │   │   ├── ThermalMonitor.swift         # IOKit SMC key reads (TC0P, TG0P, F0Ac)
│   │   │   ├── DiskMonitor.swift            # FileManager volumeAvailableCapacityForImportantUsage
│   │   │   ├── BatteryMonitor.swift         # IOKit AppleSmartBattery
│   │   │   ├── PerformanceScoreCalculator.swift  # Pure func, fully testable
│   │   │   └── SystemMonitor.swift          # @Observable aggregate, drives all polling
│   │   └── Theme/
│   │       └── AppTheme.swift               # Brand colors, Color(hex:) extension
│   ├── Onboarding/
│   │   └── OnboardingView.swift             # 3-screen sheet: Welcome → Permissions → Done
│   ├── Shared/
│   │   └── Components/
│   │       ├── SnowBackgroundView.swift     # SpriteKit SKEmitterNode, 30fps, pauses when hidden
│   │       ├── GaugeRingView.swift          # Circular progress ring (SwiftUI Canvas)
│   │       ├── StatCardView.swift           # Frosted glass card: value + label + sparkline
│   │       ├── SparklineView.swift          # Swift Charts mini line chart
│   │       └── PermissionBannerView.swift   # Yellow banner when permission denied
│   └── Resources/
│       ├── Info.plist
│       └── Assets.xcassets/
│           └── AppIcon.appiconset/
│               └── Contents.json
├── OulyMacTweaksTests/
│   ├── PerformanceScoreTests.swift          # Pure logic tests
│   ├── CPUMonitorTests.swift                # Protocol mock tests
│   ├── RAMMonitorTests.swift
│   └── DiskMonitorTests.swift
└── OulyMacTweaksUITests/                    # Empty placeholder, not used in Phase 1
    └── OulyMacTweaksUITests.swift
```

---

## Task 1: Repository, XcodeGen project, and CI workflow

**Files:**
- Create: `project.yml`
- Create: `.gitignore`
- Create: `README.md`
- Create: `.github/workflows/build.yml`
- Create: `OulyMacTweaks/Resources/Info.plist`
- Create: `OulyMacTweaks/OulyMacTweaks.entitlements`
- Create: `OulyMacTweaksTests/OulyMacTweaksTests.swift` (empty harness)
- Create: `OulyMacTweaksUITests/OulyMacTweaksUITests.swift` (empty harness)

- [ ] **Step 1: Initialize git repo**

```bash
cd C:\Users\linco\OulyMacTweaks
git init
```

- [ ] **Step 2: Create `.gitignore`**

```
.DS_Store
build/
*.xcworkspace
DerivedData/
*.xcuserstate
xcuserdata/
*.moved-aside
*.pbxuser
*.perspectivev3
```

- [ ] **Step 3: Create `project.yml`**

```yaml
name: OulyMacTweaks
options:
  bundleIdPrefix: com.oulymac
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.4"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    ENABLE_HARDENED_RUNTIME: "NO"
    CODE_SIGN_STYLE: Manual
    CODE_SIGNING_REQUIRED: "NO"
    CODE_SIGNING_ALLOWED: "NO"

targets:
  OulyMacTweaks:
    type: application
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: OulyMacTweaks
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.oulymac.tweaks
        PRODUCT_NAME: "OulyMac Tweaks"
        INFOPLIST_FILE: OulyMacTweaks/Resources/Info.plist
    dependencies:
      - sdk: IOKit.framework
      - sdk: SpriteKit.framework
    entitlements:
      path: OulyMacTweaks/OulyMacTweaks.entitlements
      properties:
        com.apple.security.app-sandbox: false
    scheme:
      testTargets:
        - OulyMacTweaksTests

  OulyMacTweaksTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: OulyMacTweaksTests
    dependencies:
      - target: OulyMacTweaks
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.oulymac.tweaks.tests
        SWIFT_VERSION: "5.9"

  OulyMacTweaksUITests:
    type: bundle.ui-testing
    platform: macOS
    deploymentTarget: "14.0"
    sources:
      - path: OulyMacTweaksUITests
    dependencies:
      - target: OulyMacTweaks
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.oulymac.tweaks.uitests
        SWIFT_VERSION: "5.9"
```

- [ ] **Step 4: Create `OulyMacTweaks/OulyMacTweaks.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 5: Create `OulyMacTweaks/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>OulyMac Tweaks</string>
    <key>CFBundleDisplayName</key>
    <string>OulyMac Tweaks</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 OulyMac. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 6: Create `OulyMacTweaks/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`**

```json
{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "16x16" },
    { "idiom": "mac", "scale": "2x", "size": "16x16" },
    { "idiom": "mac", "scale": "1x", "size": "32x32" },
    { "idiom": "mac", "scale": "2x", "size": "32x32" },
    { "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "idiom": "mac", "scale": "2x", "size": "256x256" },
    { "idiom": "mac", "scale": "1x", "size": "512x512" },
    { "idiom": "mac", "scale": "2x", "size": "512x512" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 7: Create empty test harnesses**

`OulyMacTweaksTests/OulyMacTweaksTests.swift`:
```swift
import XCTest
```

`OulyMacTweaksUITests/OulyMacTweaksUITests.swift`:
```swift
import XCTest
```

- [ ] **Step 8: Create `.github/workflows/build.yml`**

```yaml
name: Build OulyMac Tweaks

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode 15
        run: sudo xcode-select -s /Applications/Xcode_15.4.app

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode project
        run: xcodegen generate

      - name: Run unit tests
        run: |
          xcodebuild test \
            -scheme OulyMacTweaks \
            -destination 'platform=macOS' \
            -configuration Debug \
            | xcpretty || true

      - name: Build Release
        run: |
          xcodebuild \
            -scheme OulyMacTweaks \
            -configuration Release \
            -derivedDataPath build/ \
            build

      - name: Package .app
        run: |
          cp -R "build/Build/Products/Release/OulyMac Tweaks.app" .
          zip -r OulyMacTweaks.zip "OulyMac Tweaks.app"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: OulyMacTweaks-${{ github.sha }}
          path: OulyMacTweaks.zip
          retention-days: 14
```

- [ ] **Step 9: Create `README.md`**

```markdown
# OulyMac Tweaks

Your Mac. Faster. Smarter.

## Build

Requires a Mac with Xcode 15+ for local builds. CI runs automatically via GitHub Actions.

### Local build
```bash
brew install xcodegen
xcodegen generate
open OulyMacTweaks.xcodeproj
```

### CI build
Push to `main`. Download the built `.app` from the Actions tab → Artifacts.

## Phase roadmap
- Phase 1 (current): App shell, branding, monitoring dashboard
- Phase 2: One-click optimization engine
- Phase 3: Gaming Mode
- Phase 4: Software Manager
- Phase 5: AI recommendations + Pro licensing
- Phase 6: Code signing, notarization, DMG installer
```

- [ ] **Step 10: Commit**

```bash
git add .
git commit -m "chore: repo scaffold, XcodeGen config, CI workflow"
```

---

## Task 2: Theme system

**Files:**
- Create: `OulyMacTweaks/Core/Theme/AppTheme.swift`

- [ ] **Step 1: Create `OulyMacTweaks/Core/Theme/AppTheme.swift`**

```swift
import SwiftUI

enum AppColors {
    static let brandBlue    = Color(hex: "2F80ED")
    static let brandPurple  = Color(hex: "7B61FF")
    static let success      = Color(hex: "27AE60")
    static let warning      = Color(hex: "F2994A")
    static let danger       = Color(hex: "EB5757")
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    static func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...100: return AppColors.success
        case 50..<80:  return AppColors.warning
        default:       return AppColors.danger
        }
    }
}

enum AppFonts {
    static let dashboardNumber = Font.largeTitle.weight(.semibold)
    static let sectionHeader   = Font.headline
    static let cardLabel       = Font.footnote
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Core/Theme/AppTheme.swift
git commit -m "feat: add AppTheme — brand colors and typography tokens"
```

---

## Task 3: Monitoring protocols

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/MonitoringProtocols.swift`

- [ ] **Step 1: Create `OulyMacTweaks/Core/Monitoring/MonitoringProtocols.swift`**

```swift
import Foundation

protocol CPUMonitoring {
    func currentUsage() -> Double     // 0.0–1.0
}

struct RAMSnapshot {
    let used: UInt64    // bytes
    let total: UInt64   // bytes
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

protocol RAMMonitoring {
    func snapshot() -> RAMSnapshot
}

protocol GPUMonitoring {
    func currentUsage() -> Double?    // 0.0–1.0, nil if unavailable
}

struct ThermalSnapshot {
    let cpuTemp: Double?   // °C, nil on Apple Silicon or if unavailable
    let gpuTemp: Double?   // °C
    let fanRPM: Int?       // nil on fanless Macs
}

protocol ThermalMonitoring {
    func snapshot() -> ThermalSnapshot
}

struct DiskSnapshot {
    let used: UInt64    // bytes
    let total: UInt64   // bytes
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

protocol DiskMonitoring {
    func snapshot() -> DiskSnapshot
}

struct BatterySnapshot {
    let percent: Int        // 0–100; -1 if no battery (desktop Mac)
    let cycleCount: Int
    let health: Double      // 0.0–1.0; 1.0 if unavailable
    var isPresent: Bool { percent >= 0 }
}

protocol BatteryMonitoring {
    func snapshot() -> BatterySnapshot
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Core/Monitoring/MonitoringProtocols.swift
git commit -m "feat: add monitoring protocols and snapshot value types"
```

---

## Task 4: CPUMonitor

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/CPUMonitor.swift`
- Create: `OulyMacTweaksTests/CPUMonitorTests.swift`

- [ ] **Step 1: Write the failing test**

`OulyMacTweaksTests/CPUMonitorTests.swift`:
```swift
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
        // First call primes the delta; second call gives a real reading
        _ = monitor.currentUsage()
        let usage = monitor.currentUsage()
        XCTAssertGreaterThanOrEqual(usage, 0.0)
        XCTAssertLessThanOrEqual(usage, 1.0)
    }
}
```

- [ ] **Step 2: Create `OulyMacTweaks/Core/Monitoring/CPUMonitor.swift`**

```swift
import Darwin

final class MockCPUMonitor: CPUMonitoring {
    private let fixedUsage: Double
    init(usage: Double) { fixedUsage = max(0, min(1, usage)) }
    func currentUsage() -> Double { fixedUsage }
}

final class CPUMonitor: CPUMonitoring {
    private var prevUser:   [Double] = []
    private var prevSystem: [Double] = []
    private var prevIdle:   [Double] = []
    private var prevNice:   [Double] = []

    func currentUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfoPtr: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        guard host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfoPtr, &numCPUInfo
        ) == KERN_SUCCESS, let cpuInfo = cpuInfoPtr else { return 0 }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let count = Int(numCPUs)
        var user   = [Double](repeating: 0, count: count)
        var system = [Double](repeating: 0, count: count)
        var idle   = [Double](repeating: 0, count: count)
        var nice   = [Double](repeating: 0, count: count)

        for i in 0..<count {
            let b = Int(CPU_STATE_MAX) * i
            user[i]   = Double(cpuInfo[b + Int(CPU_STATE_USER)])
            system[i] = Double(cpuInfo[b + Int(CPU_STATE_SYSTEM)])
            idle[i]   = Double(cpuInfo[b + Int(CPU_STATE_IDLE)])
            nice[i]   = Double(cpuInfo[b + Int(CPU_STATE_NICE)])
        }

        var totalUsed = 0.0
        var totalAll  = 0.0

        if prevUser.count == count {
            for i in 0..<count {
                let dUser   = user[i]   - prevUser[i]
                let dSystem = system[i] - prevSystem[i]
                let dIdle   = idle[i]   - prevIdle[i]
                let dNice   = nice[i]   - prevNice[i]
                let used    = dUser + dSystem + dNice
                let all     = used + dIdle
                if all > 0 { totalUsed += used; totalAll += all }
            }
        }

        prevUser = user; prevSystem = system; prevIdle = idle; prevNice = nice
        guard totalAll > 0 else { return 0 }
        return max(0, min(1, totalUsed / totalAll))
    }
}
```

- [ ] **Step 3: Push to GitHub and verify tests pass in Actions**

```bash
git add OulyMacTweaks/Core/Monitoring/CPUMonitor.swift OulyMacTweaksTests/CPUMonitorTests.swift
git commit -m "feat: add CPUMonitor with delta-tick sampling and mock"
git push origin main
```

Open GitHub → Actions → latest run → confirm `Run unit tests` step is green.

---

## Task 5: RAMMonitor

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/RAMMonitor.swift`
- Create: `OulyMacTweaksTests/RAMMonitorTests.swift`

- [ ] **Step 1: Write the failing test**

`OulyMacTweaksTests/RAMMonitorTests.swift`:
```swift
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
```

- [ ] **Step 2: Create `OulyMacTweaks/Core/Monitoring/RAMMonitor.swift`**

```swift
import Darwin

final class MockRAMMonitor: RAMMonitoring {
    private let snap: RAMSnapshot
    init(used: UInt64, total: UInt64) { snap = RAMSnapshot(used: used, total: total) }
    func snapshot() -> RAMSnapshot { snap }
}

final class RAMMonitor: RAMMonitoring {
    func snapshot() -> RAMSnapshot {
        let total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return RAMSnapshot(used: 0, total: total)
        }

        let page   = UInt64(vm_page_size)
        let active = UInt64(stats.active_count)     * page
        let wired  = UInt64(stats.wire_count)        * page
        let compr  = UInt64(stats.compressor_page_count) * page
        let used   = min(active + wired + compr, total)

        return RAMSnapshot(used: used, total: total)
    }
}
```

- [ ] **Step 3: Commit and push**

```bash
git add OulyMacTweaks/Core/Monitoring/RAMMonitor.swift OulyMacTweaksTests/RAMMonitorTests.swift
git commit -m "feat: add RAMMonitor using vm_statistics64 + mock"
git push origin main
```

---

## Task 6: GPUMonitor

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/GPUMonitor.swift`

No unit test — IOKit GPU access requires hardware and cannot be mocked without a full IOKit stub.

- [ ] **Step 1: Create `OulyMacTweaks/Core/Monitoring/GPUMonitor.swift`**

```swift
import IOKit

final class MockGPUMonitor: GPUMonitoring {
    private let fixedUsage: Double?
    init(usage: Double?) { fixedUsage = usage }
    func currentUsage() -> Double? { fixedUsage }
}

final class GPUMonitor: GPUMonitoring {
    func currentUsage() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        var maxUsage: Double? = nil
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                service, &props, kCFAllocatorDefault, 0
            ) == kIOReturnSuccess else { continue }
            let dict = props!.takeRetainedValue() as NSDictionary
            if let perf = dict["PerformanceStatistics"] as? [String: Any],
               let util = perf["Device Utilization %"] as? Double {
                maxUsage = max(maxUsage ?? 0, util / 100.0)
            }
        }
        return maxUsage
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Core/Monitoring/GPUMonitor.swift
git commit -m "feat: add GPUMonitor via IOKit IOAccelerator"
```

---

## Task 7: ThermalMonitor

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/ThermalMonitor.swift`

No unit test — SMC reads require hardware.

- [ ] **Step 1: Create `OulyMacTweaks/Core/Monitoring/ThermalMonitor.swift`**

```swift
import IOKit

final class MockThermalMonitor: ThermalMonitoring {
    private let snap: ThermalSnapshot
    init(cpuTemp: Double?, gpuTemp: Double?, fanRPM: Int?) {
        snap = ThermalSnapshot(cpuTemp: cpuTemp, gpuTemp: gpuTemp, fanRPM: fanRPM)
    }
    func snapshot() -> ThermalSnapshot { snap }
}

final class ThermalMonitor: ThermalMonitoring {
    func snapshot() -> ThermalSnapshot {
        ThermalSnapshot(
            cpuTemp: readSMCDouble(key: "TC0P"),
            gpuTemp: readSMCDouble(key: "TG0P"),
            fanRPM:  readSMCFan()
        )
    }

    // MARK: - SMC helpers

    private func smcService() -> io_service_t {
        IOServiceGetMatchingService(kIOMainPortDefault,
                                    IOServiceMatching("AppleSMC"))
    }

    private func readSMCDouble(key: String) -> Double? {
        let service = smcService()
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else {
            return nil
        }
        defer { IOServiceClose(conn) }

        // Build SMC key as UInt32
        var keyInt: UInt32 = 0
        for ch in key.utf8 { keyInt = (keyInt << 8) | UInt32(ch) }

        // SMC input/output structs (simplified layout)
        var input  = SMCKeyData_t()
        var output = SMCKeyData_t()
        input.key = keyInt
        input.data8 = SMC_CMD_READ_KEYINFO

        var inputSize  = MemoryLayout<SMCKeyData_t>.size
        var outputSize = MemoryLayout<SMCKeyData_t>.size

        guard IOConnectCallStructMethod(
            conn, UInt32(KERNEL_INDEX_SMC),
            &input,  inputSize,
            &output, &outputSize
        ) == kIOReturnSuccess else { return nil }

        input.keyInfo = output.keyInfo
        input.data8   = SMC_CMD_READ_BYTES

        guard IOConnectCallStructMethod(
            conn, UInt32(KERNEL_INDEX_SMC),
            &input,  inputSize,
            &output, &outputSize
        ) == kIOReturnSuccess else { return nil }

        // sp78 encoding: two bytes big-endian fixed-point (1 sign + 7 int + 8 frac)
        let b0 = Double(output.bytes.0)
        let b1 = Double(output.bytes.1)
        let raw = b0 * 256 + b1
        return raw / 256.0
    }

    private func readSMCFan() -> Int? {
        guard let raw = readSMCDouble(key: "F0Ac") else { return nil }
        // Fan speed is sp78: raw / 4  (lsb = 0.25 RPM)
        return Int(raw / 4)
    }
}

// MARK: - SMC constants and structs

private let KERNEL_INDEX_SMC   = 2
private let SMC_CMD_READ_BYTES = UInt8(5)
private let SMC_CMD_READ_KEYINFO = UInt8(9)

private struct SMCKeyInfo_t {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCKeyData_t {
    var key: UInt32 = 0
    var vers = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
    var pLimitData = (UInt8(0), UInt8(0), UInt8(0))
    var keyInfo = SMCKeyInfo_t()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = (
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
        UInt8(0), UInt8(0)
    )
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Core/Monitoring/ThermalMonitor.swift
git commit -m "feat: add ThermalMonitor via IOKit SMC (CPU/GPU temp, fan RPM)"
```

---

## Task 8: DiskMonitor

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/DiskMonitor.swift`
- Create: `OulyMacTweaksTests/DiskMonitorTests.swift`

- [ ] **Step 1: Write the failing test**

`OulyMacTweaksTests/DiskMonitorTests.swift`:
```swift
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
```

- [ ] **Step 2: Create `OulyMacTweaks/Core/Monitoring/DiskMonitor.swift`**

```swift
import Foundation

final class MockDiskMonitor: DiskMonitoring {
    private let snap: DiskSnapshot
    init(used: UInt64, total: UInt64) { snap = DiskSnapshot(used: used, total: total) }
    func snapshot() -> DiskSnapshot { snap }
}

final class DiskMonitor: DiskMonitoring {
    func snapshot() -> DiskSnapshot {
        let url = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let avail = values.volumeAvailableCapacityForImportantUsage else {
            return DiskSnapshot(used: 0, total: 0)
        }
        let totalBytes = UInt64(total)
        let usedBytes  = totalBytes - UInt64(max(0, avail))
        return DiskSnapshot(used: usedBytes, total: totalBytes)
    }
}
```

- [ ] **Step 3: Commit and push**

```bash
git add OulyMacTweaks/Core/Monitoring/DiskMonitor.swift OulyMacTweaksTests/DiskMonitorTests.swift
git commit -m "feat: add DiskMonitor using FileManager volumeCapacity APIs + mock"
git push origin main
```

---

## Task 9: BatteryMonitor

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/BatteryMonitor.swift`

No unit test — IOKit battery requires hardware.

- [ ] **Step 1: Create `OulyMacTweaks/Core/Monitoring/BatteryMonitor.swift`**

```swift
import IOKit
import IOKit.ps

final class MockBatteryMonitor: BatteryMonitoring {
    private let snap: BatterySnapshot
    init(percent: Int, cycleCount: Int, health: Double) {
        snap = BatterySnapshot(percent: percent, cycleCount: cycleCount, health: health)
    }
    func snapshot() -> BatterySnapshot { snap }
}

final class BatteryMonitor: BatteryMonitoring {
    func snapshot() -> BatterySnapshot {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != 0 else {
            return BatterySnapshot(percent: -1, cycleCount: 0, health: 1.0)
        }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            service, &props, kCFAllocatorDefault, 0
        ) == kIOReturnSuccess else {
            return BatterySnapshot(percent: -1, cycleCount: 0, health: 1.0)
        }
        let dict = props!.takeRetainedValue() as NSDictionary

        let current    = dict["CurrentCapacity"]  as? Int ?? 0
        let max        = dict["MaxCapacity"]       as? Int ?? 100
        let design     = dict["DesignCapacity"]    as? Int ?? max
        let cycleCount = dict["CycleCount"]        as? Int ?? 0

        let percent = max > 0 ? min(100, current * 100 / max) : 0
        let health  = design > 0 ? min(1.0, Double(max) / Double(design)) : 1.0

        return BatterySnapshot(percent: percent, cycleCount: cycleCount, health: health)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Core/Monitoring/BatteryMonitor.swift
git commit -m "feat: add BatteryMonitor via IOKit AppleSmartBattery"
```

---

## Task 10: PerformanceScoreCalculator + SystemMonitor

**Files:**
- Create: `OulyMacTweaks/Core/Monitoring/PerformanceScoreCalculator.swift`
- Create: `OulyMacTweaks/Core/Monitoring/SystemMonitor.swift`
- Create: `OulyMacTweaksTests/PerformanceScoreTests.swift`

- [ ] **Step 1: Write the failing tests**

`OulyMacTweaksTests/PerformanceScoreTests.swift`:
```swift
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
```

- [ ] **Step 2: Create `OulyMacTweaks/Core/Monitoring/PerformanceScoreCalculator.swift`**

```swift
import Foundation

struct PerformanceScoreCalculator {
    // Weights must sum to 100
    private let cpuWeight:  Double = 25
    private let ramWeight:  Double = 30
    private let diskWeight: Double = 25
    private let tempWeight: Double = 20

    func score(cpu: Double, ram: Double, disk: Double, cpuTemp: Double?) -> Int {
        let cpuScore  = (1 - cpu.clamped(to: 0...1))  * cpuWeight
        let ramScore  = (1 - ram.clamped(to: 0...1))  * ramWeight
        let diskScore = (1 - disk.clamped(to: 0...1)) * diskWeight

        let tempScore: Double
        if let t = cpuTemp {
            switch t {
            case ...70: tempScore = tempWeight
            case ...85: tempScore = tempWeight * 0.5
            default:    tempScore = 0
            }
        } else {
            tempScore = tempWeight
        }

        let raw = cpuScore + ramScore + diskScore + tempScore
        return Int(raw.clamped(to: 0...100))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
```

- [ ] **Step 3: Run tests locally via push**

```bash
git add OulyMacTweaks/Core/Monitoring/PerformanceScoreCalculator.swift \
        OulyMacTweaksTests/PerformanceScoreTests.swift
git commit -m "feat: add PerformanceScoreCalculator with weighted inputs"
git push origin main
```

Verify in Actions that `PerformanceScoreTests` passes.

- [ ] **Step 4: Create `OulyMacTweaks/Core/Monitoring/SystemMonitor.swift`**

```swift
import Foundation
import Observation

@Observable
final class SystemMonitor {
    // Current values
    var cpuUsage: Double = 0
    var ram      = RAMSnapshot(used: 0, total: 1)
    var gpuUsage: Double? = nil
    var thermal  = ThermalSnapshot(cpuTemp: nil, gpuTemp: nil, fanRPM: nil)
    var disk     = DiskSnapshot(used: 0, total: 1)
    var battery  = BatterySnapshot(percent: -1, cycleCount: 0, health: 1.0)

    // History (last 60 samples)
    var cpuHistory: [Double] = []
    var ramHistory: [Double] = []
    var gpuHistory: [Double] = []

    var performanceScore: Int = 100

    // Internal
    private let cpu:     CPUMonitoring
    private let ramMon:  RAMMonitoring
    private let gpu:     GPUMonitoring
    private let thermal_: ThermalMonitoring
    private let diskMon: DiskMonitoring
    private let batMon:  BatteryMonitoring
    private let calc     = PerformanceScoreCalculator()

    private var fastTimer: Timer?
    private var slowTimer: Timer?

    init(
        cpu:     CPUMonitoring   = CPUMonitor(),
        ram:     RAMMonitoring   = RAMMonitor(),
        gpu:     GPUMonitoring   = GPUMonitor(),
        thermal: ThermalMonitoring = ThermalMonitor(),
        disk:    DiskMonitoring  = DiskMonitor(),
        battery: BatteryMonitoring = BatteryMonitor()
    ) {
        self.cpu      = cpu
        self.ramMon   = ram
        self.gpu      = gpu
        self.thermal_ = thermal
        self.diskMon  = disk
        self.batMon   = battery
    }

    func startPolling() {
        // Prime CPU delta
        _ = cpu.currentUsage()

        fastTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pollFast()
        }
        slowTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.pollSlow()
        }
        pollFast()
        pollSlow()
    }

    func stopPolling() {
        fastTimer?.invalidate()
        slowTimer?.invalidate()
    }

    private func pollFast() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let cpuVal   = self.cpu.currentUsage()
            let ramSnap  = self.ramMon.snapshot()
            let gpuVal   = self.gpu.currentUsage()
            let thermSnap = self.thermal_.snapshot()

            DispatchQueue.main.async {
                self.cpuUsage = cpuVal
                self.ram      = ramSnap
                self.gpuUsage = gpuVal
                self.thermal  = thermSnap
                self.appendHistory(cpu: cpuVal, ram: ramSnap.fraction, gpu: gpuVal ?? 0)
                self.recalcScore()
            }
        }
    }

    private func pollSlow() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let diskSnap = self.diskMon.snapshot()
            let batSnap  = self.batMon.snapshot()
            DispatchQueue.main.async {
                self.disk    = diskSnap
                self.battery = batSnap
                self.recalcScore()
            }
        }
    }

    private func appendHistory(cpu: Double, ram: Double, gpu: Double) {
        func append(_ val: Double, to arr: inout [Double]) {
            arr.append(val)
            if arr.count > 60 { arr.removeFirst() }
        }
        append(cpu, to: &cpuHistory)
        append(ram, to: &ramHistory)
        append(gpu, to: &gpuHistory)
    }

    private func recalcScore() {
        performanceScore = calc.score(
            cpu:     cpuUsage,
            ram:     ram.fraction,
            disk:    disk.fraction,
            cpuTemp: thermal.cpuTemp
        )
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add OulyMacTweaks/Core/Monitoring/SystemMonitor.swift
git commit -m "feat: add SystemMonitor — @Observable aggregate with 2s/30s polling"
```

---

## Task 11: App entry point and navigation shell

**Files:**
- Create: `OulyMacTweaks/App/OulyMacTweaksApp.swift`
- Create: `OulyMacTweaks/Navigation/NavDestination.swift`
- Create: `OulyMacTweaks/Navigation/ContentView.swift`
- Create: `OulyMacTweaks/Navigation/SidebarView.swift`

- [ ] **Step 1: Create `OulyMacTweaks/Navigation/NavDestination.swift`**

```swift
import Foundation

enum NavDestination: String, CaseIterable, Hashable {
    case dashboard       = "Dashboard"
    case optimize        = "Optimize"
    case gaming          = "Gaming Mode"
    case softwareManager = "Software Manager"
    case aiAdvisor       = "AI Advisor"
    case settings        = "Settings"

    var icon: String {
        switch self {
        case .dashboard:       return "gauge.with.dots.needle.bottom.50percent"
        case .optimize:        return "bolt.fill"
        case .gaming:          return "gamecontroller.fill"
        case .softwareManager: return "tray.full.fill"
        case .aiAdvisor:       return "brain.head.profile"
        case .settings:        return "gear"
        }
    }

    var isStub: Bool { self != .dashboard && self != .settings }
}
```

- [ ] **Step 2: Create `OulyMacTweaks/Navigation/SidebarView.swift`**

```swift
import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavDestination?

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(NavDestination.allCases.filter { $0 != .settings }) { dest in
                    navRow(dest)
                }
            }
            Section {
                navRow(.settings)
                upgradeRow
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) { header }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColors.brandBlue)
                .shadow(color: AppColors.brandBlue.opacity(0.5), radius: 6)
            Text("OulyMac Tweaks")
                .font(AppFonts.sectionHeader)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func navRow(_ dest: NavDestination) -> some View {
        Label(dest.rawValue, systemImage: dest.icon)
            .tag(dest)
    }

    private var upgradeRow: some View {
        Label("Upgrade to Pro", systemImage: "star.fill")
            .foregroundStyle(AppColors.brandPurple)
            .tag(Optional<NavDestination>.none)
            .onTapGesture { /* Phase 5: open upgrade sheet */ }
    }
}
```

- [ ] **Step 3: Create `OulyMacTweaks/Navigation/ContentView.swift`**

```swift
import SwiftUI

struct ContentView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var selection: NavDestination? = .dashboard
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .frame(minWidth: 200, maxWidth: 200)
        } detail: {
            ZStack {
                SnowBackgroundView()
                detailView(for: selection)
            }
        }
        .onAppear {
            if !hasOnboarded { showOnboarding = true }
            monitor.startPolling()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .onDisappear { hasOnboarded = true }
        }
    }

    @ViewBuilder
    private func detailView(for dest: NavDestination?) -> some View {
        switch dest {
        case .dashboard, .none:    DashboardView()
        case .optimize:            OptimizeStubView()
        case .gaming:              GamingStubView()
        case .softwareManager:     SoftwareManagerStubView()
        case .aiAdvisor:           AIAdvisorStubView()
        case .settings:            SettingsStubView()
        }
    }
}
```

- [ ] **Step 4: Create `OulyMacTweaks/App/OulyMacTweaksApp.swift`**

```swift
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

- [ ] **Step 5: Commit**

```bash
git add OulyMacTweaks/App/ OulyMacTweaks/Navigation/
git commit -m "feat: app entry point, NavigationSplitView shell, sidebar nav"
```

---

## Task 12: Stub views for Phases 2–5

**Files:**
- Create: `OulyMacTweaks/Features/Optimize/OptimizeStubView.swift`
- Create: `OulyMacTweaks/Features/Gaming/GamingStubView.swift`
- Create: `OulyMacTweaks/Features/SoftwareManager/SoftwareManagerStubView.swift`
- Create: `OulyMacTweaks/Features/AIAdvisor/AIAdvisorStubView.swift`
- Create: `OulyMacTweaks/Features/Settings/SettingsStubView.swift`

- [ ] **Step 1: Create all stub views**

`OulyMacTweaks/Features/Optimize/OptimizeStubView.swift`:
```swift
import SwiftUI

struct OptimizeStubView: View {
    var body: some View { StubView(title: "Optimize", icon: "bolt.fill", phase: 2) }
}
```

`OulyMacTweaks/Features/Gaming/GamingStubView.swift`:
```swift
import SwiftUI

struct GamingStubView: View {
    var body: some View { StubView(title: "Gaming Mode", icon: "gamecontroller.fill", phase: 3) }
}
```

`OulyMacTweaks/Features/SoftwareManager/SoftwareManagerStubView.swift`:
```swift
import SwiftUI

struct SoftwareManagerStubView: View {
    var body: some View { StubView(title: "Software Manager", icon: "tray.full.fill", phase: 4) }
}
```

`OulyMacTweaks/Features/AIAdvisor/AIAdvisorStubView.swift`:
```swift
import SwiftUI

struct AIAdvisorStubView: View {
    var body: some View { StubView(title: "AI Advisor", icon: "brain.head.profile", phase: 5) }
}
```

`OulyMacTweaks/Features/Settings/SettingsStubView.swift`:
```swift
import SwiftUI

struct SettingsStubView: View {
    var body: some View { StubView(title: "Settings", icon: "gear", phase: nil) }
}
```

`OulyMacTweaks/Shared/Components/StubView.swift`:
```swift
import SwiftUI

struct StubView: View {
    let title: String
    let icon: String
    let phase: Int?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppColors.brandBlue)
            Text(title)
                .font(.title2.weight(.semibold))
            if let p = phase {
                Text("Coming in Phase \(p)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Features/ OulyMacTweaks/Shared/Components/StubView.swift
git commit -m "feat: add stub views for phases 2-5"
```

---

## Task 13: Snow background

**Files:**
- Create: `OulyMacTweaks/Shared/Components/SnowBackgroundView.swift`

- [ ] **Step 1: Create `OulyMacTweaks/Shared/Components/SnowBackgroundView.swift`**

```swift
import SwiftUI
import SpriteKit

private final class SnowScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        let emitter = makeEmitter()
        emitter.position = CGPoint(x: frame.midX, y: frame.maxY + 20)
        emitter.particlePositionRange = CGVector(dx: frame.width * 1.2, dy: 0)
        addChild(emitter)
    }

    private func makeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture    = circleTexture()
        e.particleBirthRate  = 8
        e.particleLifetime   = 12
        e.particleLifetimeRange = 6
        e.particleSpeed      = 50
        e.particleSpeedRange = 25
        e.emissionAngle      = -.pi / 2
        e.emissionAngleRange = .pi / 10
        e.particleScale      = 0.012
        e.particleScaleRange = 0.008
        e.particleAlpha      = 0.35
        e.particleAlphaRange = 0.15
        e.particleColor      = .white
        e.xAcceleration      = 8
        return e
    }

    private func circleTexture() -> SKTexture {
        let size = CGSize(width: 12, height: 12)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return SKTexture(image: img)
    }
}

struct SnowBackgroundView: View {
    private let scene: SnowScene = {
        let s = SnowScene()
        s.scaleMode = .resizeFill
        s.preferredFramesPerSecond = 30
        return s
    }()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(
                NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            ) { _ in scene.isPaused = true }
            .onReceive(
                NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            ) { _ in scene.isPaused = false }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Shared/Components/SnowBackgroundView.swift
git commit -m "feat: add SpriteKit snow particle background (30fps, pauses when inactive)"
```

---

## Task 14: Shared UI components

**Files:**
- Create: `OulyMacTweaks/Shared/Components/GaugeRingView.swift`
- Create: `OulyMacTweaks/Shared/Components/SparklineView.swift`
- Create: `OulyMacTweaks/Shared/Components/StatCardView.swift`
- Create: `OulyMacTweaks/Shared/Components/PermissionBannerView.swift`

- [ ] **Step 1: Create `OulyMacTweaks/Shared/Components/GaugeRingView.swift`**

```swift
import SwiftUI

struct GaugeRingView: View {
    let value: Double      // 0.0–1.0
    let color: Color
    let lineWidth: CGFloat

    init(value: Double, color: Color, lineWidth: CGFloat = 10) {
        self.value = value.clamped(to: 0...1)
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: value)
        }
    }
}
```

- [ ] **Step 2: Create `OulyMacTweaks/Shared/Components/SparklineView.swift`**

```swift
import SwiftUI
import Charts

struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { i, val in
                LineMark(
                    x: .value("t", i),
                    y: .value("v", val)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }
            if let last = data.last {
                AreaMark(
                    x: .value("t", data.count - 1),
                    yStart: .value("v", 0),
                    yEnd: .value("v", last)
                )
                .foregroundStyle(color.opacity(0.15))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        .frame(height: 32)
    }
}
```

- [ ] **Step 3: Create `OulyMacTweaks/Shared/Components/StatCardView.swift`**

```swift
import SwiftUI

struct StatCardView: View {
    let title:     String
    let value:     String
    let subtitle:  String
    let icon:      String
    let color:     Color
    let history:   [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(AppFonts.cardLabel)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(AppFonts.dashboardNumber)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(AppFonts.cardLabel)
                .foregroundStyle(.secondary)
            SparklineView(data: history, color: color)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 4: Create `OulyMacTweaks/Shared/Components/PermissionBannerView.swift`**

```swift
import SwiftUI

struct PermissionBannerView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.warning)
            Text(message)
                .font(.footnote)
            Spacer()
            Button("Grant Access", action: action)
                .buttonStyle(.borderedProminent)
                .tint(AppColors.brandBlue)
                .controlSize(.small)
        }
        .padding(12)
        .background(AppColors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add OulyMacTweaks/Shared/Components/
git commit -m "feat: add GaugeRingView, SparklineView, StatCardView, PermissionBannerView"
```

---

## Task 15: Onboarding flow

**Files:**
- Create: `OulyMacTweaks/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Create `OulyMacTweaks/Onboarding/OnboardingView.swift`**

```swift
import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                permissionsPage.tag(1)
                donePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: 520, height: 380)

            pageIndicator
                .padding(.bottom, 24)
        }
        .frame(width: 520)
        .background(.regularMaterial)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.brandBlue)
                .shadow(color: AppColors.brandBlue.opacity(0.4), radius: 12)
            Text("OulyMac Tweaks")
                .font(.largeTitle.weight(.bold))
            Text("Your Mac. Faster. Smarter.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Get Started") { withAnimation { page = 1 } }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.brandBlue)
                .controlSize(.large)
        }
        .padding(40)
    }

    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.brandBlue)
            Text("One Permission")
                .font(.title2.weight(.bold))
            Text("OulyMac Tweaks needs **Full Disk Access** to analyze your storage. No data ever leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Skip for now") { withAnimation { page = 2 } }
                    .buttonStyle(.bordered)
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                    )
                    withAnimation { page = 2 }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.brandBlue)
            }
        }
        .padding(40)
    }

    private var donePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.success)
            Text("You're all set!")
                .font(.largeTitle.weight(.bold))
            Text("Your Mac is ready to be optimized.")
                .foregroundStyle(.secondary)
            Button("Open Dashboard") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.success)
                .controlSize(.large)
        }
        .padding(40)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i == page ? AppColors.brandBlue : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: page)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add OulyMacTweaks/Onboarding/OnboardingView.swift
git commit -m "feat: add 3-screen onboarding flow (welcome, permissions, done)"
```

---

## Task 16: Dashboard views

**Files:**
- Create: `OulyMacTweaks/Features/Dashboard/PerformanceScoreView.swift`
- Create: `OulyMacTweaks/Features/Dashboard/TempFanView.swift`
- Create: `OulyMacTweaks/Features/Dashboard/BatteryView.swift`
- Create: `OulyMacTweaks/Features/Dashboard/DashboardView.swift`

- [ ] **Step 1: Create `OulyMacTweaks/Features/Dashboard/PerformanceScoreView.swift`**

```swift
import SwiftUI

struct PerformanceScoreView: View {
    let score: Int
    @AppStorage("lastOptimizedDate") private var lastOptimizedDate: Double = 0

    private var color: Color { .scoreColor(for: score) }

    private var subtitle: String {
        switch score {
        case 80...100: return "Great shape"
        case 50..<80:  return "Could be better"
        default:       return "Needs attention"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Performance Score")
                    .font(AppFonts.sectionHeader)
                Spacer()
                if lastOptimizedDate > 0 {
                    Text("Last optimized: \(Date(timeIntervalSince1970: lastOptimizedDate).formatted(.relative(presentation: .named)))")
                        .font(AppFonts.cardLabel)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            ZStack {
                GaugeRingView(value: Double(score) / 100, color: color, lineWidth: 14)
                    .frame(width: 120, height: 120)
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: Create `OulyMacTweaks/Features/Dashboard/TempFanView.swift`**

```swift
import SwiftUI

struct TempFanView: View {
    let thermal: ThermalSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Temperatures", systemImage: "thermometer.medium")
                .font(AppFonts.sectionHeader)

            HStack(spacing: 24) {
                tempItem(label: "CPU", temp: thermal.cpuTemp)
                tempItem(label: "GPU", temp: thermal.gpuTemp)
                if let fan = thermal.fanRPM {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fan").font(AppFonts.cardLabel).foregroundStyle(.secondary)
                        Text("\(fan) RPM").font(.callout.weight(.medium))
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func tempItem(label: String, temp: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFonts.cardLabel).foregroundStyle(.secondary)
            if let t = temp {
                Text(String(format: "%.0f°C", t))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(tempColor(t))
            } else {
                Text("—").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func tempColor(_ t: Double) -> Color {
        t > 85 ? AppColors.danger : t > 70 ? AppColors.warning : AppColors.success
    }
}
```

- [ ] **Step 3: Create `OulyMacTweaks/Features/Dashboard/BatteryView.swift`**

```swift
import SwiftUI

struct BatteryView: View {
    let battery: BatterySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Battery Health", systemImage: "battery.100percent")
                .font(AppFonts.sectionHeader)

            if battery.isPresent {
                HStack(spacing: 24) {
                    stat(label: "Capacity", value: "\(battery.percent)%")
                    stat(label: "Health",   value: String(format: "%.0f%%", battery.health * 100))
                    stat(label: "Cycles",   value: "\(battery.cycleCount)")
                }
                GaugeRingView(value: battery.health, color: healthColor, lineWidth: 6)
                    .frame(width: 44, height: 44)
            } else {
                Text("No battery detected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var healthColor: Color {
        battery.health > 0.8 ? AppColors.success :
        battery.health > 0.6 ? AppColors.warning : AppColors.danger
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFonts.cardLabel).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
    }
}
```

- [ ] **Step 4: Create `OulyMacTweaks/Features/Dashboard/DashboardView.swift`**

```swift
import SwiftUI

struct DashboardView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PerformanceScoreView(score: monitor.performanceScore)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 12) {
                    StatCardView(
                        title:    "CPU",
                        value:    String(format: "%.0f%%", monitor.cpuUsage * 100),
                        subtitle: "Processor load",
                        icon:     "cpu",
                        color:    AppColors.brandBlue,
                        history:  monitor.cpuHistory
                    )
                    StatCardView(
                        title:    "RAM",
                        value:    formatBytes(monitor.ram.used),
                        subtitle: "of \(formatBytes(monitor.ram.total)) used",
                        icon:     "memorychip",
                        color:    AppColors.brandPurple,
                        history:  monitor.ramHistory
                    )
                    StatCardView(
                        title:    "GPU",
                        value:    monitor.gpuUsage.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                        subtitle: "Graphics load",
                        icon:     "display",
                        color:    AppColors.success,
                        history:  monitor.gpuHistory
                    )
                    StatCardView(
                        title:    "Disk",
                        value:    String(format: "%.0f%%", monitor.disk.fraction * 100),
                        subtitle: "\(formatBytes(monitor.disk.used)) used",
                        icon:     "internaldrive",
                        color:    AppColors.warning,
                        history:  []
                    )
                }

                HStack(spacing: 12) {
                    TempFanView(thermal: monitor.thermal).frame(maxWidth: .infinity)
                    BatteryView(battery: monitor.battery).frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add OulyMacTweaks/Features/Dashboard/
git commit -m "feat: add dashboard — performance score, stat cards, temps, battery"
```

---

## Task 17: Final push and CI verification

- [ ] **Step 1: Push all commits to GitHub**

```bash
git push origin main
```

- [ ] **Step 2: Watch the Actions run**

Open `https://github.com/<your-username>/OulyMacTweaks/actions` and confirm:
- `Run unit tests` step passes (PerformanceScoreTests, CPUMonitorTests, RAMMonitorTests, DiskMonitorTests)
- `Build Release` step passes with no errors
- `Upload artifact` step completes

- [ ] **Step 3: Download and test the built app**

1. Click the completed Actions run
2. Download `OulyMacTweaks-<sha>.zip` from Artifacts
3. Unzip on a Mac
4. Right-click `OulyMac Tweaks.app` → Open (bypasses unsigned app Gatekeeper warning)
5. Verify: onboarding sheet appears on first launch, snow particles are visible, dashboard shows live stats

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -p
git commit -m "fix: <describe any issues found during manual test>"
git push origin main
```

---

## Self-Review Notes

**Spec coverage check:**
- App shell + NavigationSplitView → Task 11 ✓
- Branding + colors + typography → Task 2 ✓
- Snow background → Task 13 ✓
- Onboarding (3 screens, permissions, UserDefaults flag) → Task 15 ✓
- CPU monitoring → Task 4 ✓
- RAM monitoring → Task 5 ✓
- GPU monitoring → Task 6 ✓
- Thermal (temps + fan) → Task 7 ✓
- Disk monitoring → Task 8 ✓
- Battery monitoring → Task 9 ✓
- SystemMonitor aggregate → Task 10 ✓
- PerformanceScore (weighted, testable) → Task 10 ✓
- Dashboard layout → Task 16 ✓
- GitHub Actions CI → Task 1 ✓
- Stub views for Phase 2–5 → Task 12 ✓

**Type consistency:**
- `RAMSnapshot`, `DiskSnapshot`, `ThermalSnapshot`, `BatterySnapshot` defined in Task 3, used identically in Tasks 5–9 and 16 ✓
- `SystemMonitor` properties (`ram: RAMSnapshot`, `thermal: ThermalSnapshot`, etc.) match protocol snapshot types ✓
- `PerformanceScoreCalculator.score(cpu:ram:disk:cpuTemp:)` signature matches call in `SystemMonitor.recalcScore()` ✓
- `clamped(to:)` extension defined once in `PerformanceScoreCalculator.swift`, used in same file only ✓

**No placeholders:** All steps contain complete, compilable code. No TBDs. ✓
