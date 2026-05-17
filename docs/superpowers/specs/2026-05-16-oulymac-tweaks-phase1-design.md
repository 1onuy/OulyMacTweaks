# OulyMac Tweaks — Phase 1 Design Spec
**Date:** 2026-05-16
**Phase:** 1 of 6 — App Shell + Branding + Monitoring Dashboard
**Status:** Approved

---

## 1. Project Overview

**App name:** OulyMac Tweaks
**Tagline:** Your Mac. Faster. Smarter.
**Platform:** macOS 14 Sonoma (minimum)
**Distribution:** Direct download — notarized DMG (not Mac App Store)
**Build environment:** GitHub Actions with `macos-14` runner
**Architecture:** NavigationSplitView with persistent sidebar

Phase 1 delivers the full app shell, branding system, onboarding flow, and live system monitoring dashboard. It is the foundation all subsequent phases build on.

---

## 2. Architecture

### Xcode Project Structure
```
OulyMacTweaks/
├── App/
│   ├── OulyMacTweaksApp.swift       # @main entry point, injects SystemMonitor
│   └── AppDelegate.swift            # Menu bar extra stub (activated Phase 2)
├── Navigation/
│   ├── ContentView.swift            # Root NavigationSplitView
│   └── SidebarView.swift            # Left sidebar (200pt fixed width)
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardView.swift      # Main dashboard layout
│   │   ├── PerformanceScoreView.swift
│   │   ├── StatCardView.swift       # Reusable metric card
│   │   ├── SparklineView.swift      # Mini chart using Swift Charts
│   │   ├── TempFanView.swift
│   │   └── BatteryView.swift
│   ├── Optimize/                    # Empty stub view (Phase 2)
│   ├── Gaming/                      # Empty stub view (Phase 3)
│   └── SoftwareManager/             # Empty stub view (Phase 4)
├── Core/
│   ├── Monitoring/
│   │   ├── SystemMonitor.swift      # @Observable, all live stats
│   │   ├── CPUMonitor.swift         # host_processor_info wrapper
│   │   ├── RAMMonitor.swift         # host_statistics64 wrapper
│   │   ├── GPUMonitor.swift         # IOKit IOAccelerator wrapper
│   │   ├── ThermalMonitor.swift     # IOKit SMC key reader
│   │   ├── DiskMonitor.swift        # FileManager volumeAvailableCapacity
│   │   └── BatteryMonitor.swift     # IOKit AppleSmartBattery
│   └── Theme/
│       ├── AppColors.swift          # Brand color tokens
│       └── AppFonts.swift           # Typography scale
├── Shared/
│   └── Components/
│       ├── GaugeRingView.swift      # Circular performance score gauge
│       ├── SnowBackgroundView.swift # SpriteKit snow particle layer
│       └── PermissionBannerView.swift
└── Resources/
    └── Assets.xcassets
```

### Technology Choices
| Concern | Solution |
|---|---|
| UI framework | SwiftUI (no AppKit mixing in Phase 1) |
| State management | `@Observable` (macOS 14+) |
| Charts | Swift Charts (native, macOS 14) |
| System stats | Mach kernel APIs + IOKit |
| Snow effect | SpriteKit `SKEmitterNode` via `SpriteView` |
| Persistence | `UserDefaults` only (no DB in Phase 1) |

---

## 3. App Shell

### Window
- Default size: 1100×700, minimum: 900×600
- Resizable, `.windowStyle(.hiddenTitleBar)`
- Traffic lights overlaid on sidebar top-left
- Background: `.windowBackground` material (auto dark/light)

### Sidebar
- Fixed 200pt width
- Header: 24×24pt app icon + "OulyMac Tweaks" in `.headline`
- Navigation items (SF Symbols icons):
  - Dashboard (`gauge.with.dots.needle.bottom.50percent`)
  - Optimize (`bolt.fill`) — stub
  - Gaming Mode (`gamecontroller.fill`) — stub
  - Software Manager (`tray.full.fill`) — stub
  - AI Advisor (`brain.head.profile`) — stub
- Divider
- Settings (`gear`)
- Upgrade to Pro (`star.fill`) — persistent upsell row, Brand Purple accent

### Onboarding (first-launch sheet)
Three screens, stored completion state in `UserDefaults(key: "hasCompletedOnboarding")`:

1. **Welcome** — app icon, name, tagline, "Get Started" button
2. **Permissions** — explains Full Disk Access need, "Open System Settings" button via `NSWorkspace.open`, "Skip for now" secondary action. Permission denial = graceful feature degradation, not a crash.
3. **Done** — "Your Mac is ready to be optimized", confetti/success animation, "Open Dashboard" button

---

## 4. Branding

### Colors
| Token | Hex | Usage |
|---|---|---|
| Brand Blue | `#2F80ED` | Primary accent, buttons, selected states |
| Brand Purple | `#7B61FF` | Gaming Mode, Pro badge |
| Success Green | `#27AE60` | Healthy stats, optimized state |
| Warning Amber | `#F2994A` | Moderate load, caution |
| Danger Red | `#EB5757` | High CPU/temp, critical alerts |
| Card Surface | `.regularMaterial` | Frosted glass cards |

### Typography
All SF Pro (system font). No custom fonts.
- Dashboard numbers: `.largeTitle` + `.semibold`
- Section headers: `.headline`
- Labels/captions: `.footnote` + `.secondary`

### App Icon
- Rounded rectangle, macOS standard shape
- Background: deep navy gradient (`#0F1B2D` → `#1A3A5C`)
- Foreground: stylized upward lightning bolt in Brand Blue + white
- Feeling: fast, technical, trustworthy

### Snow Background Effect
- Rendered via `SpriteKit` `SKEmitterNode` embedded in `SpriteView`
- Layered behind all UI using `.zIndex(-1)`, `.ignoresSafeArea()`, `.allowsHitTesting(false)`
- Visible through frosted glass card surfaces for depth effect
- Parameters:
  - Max particles: 60
  - Particle shape: small white circle (no texture asset)
  - Opacity: 0.25–0.45
  - Size: 2–5pt randomized
  - Animation: slow vertical drift + slight horizontal wobble
  - Scene FPS: capped at 30 (`preferredFramesPerSecond = 30`)
  - Paused when app backgrounded/minimized (`isPaused = true`)

---

## 5. Dashboard & Monitoring

### Layout
```
┌─────────────────────────────────────────────────────┐
│  Performance Score              [Last optimized: —] │
│  ┌──────────────────────────────────────────────┐   │
│  │  Circular gauge ring    Score: 84/100        │   │
│  │  "Good — 3 recommendations"                  │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │ CPU      │ │ RAM      │ │ GPU      │ │ Disk   │ │
│  │ 23%      │ │ 6.2 GB   │ │ 14%      │ │ 74%    │ │
│  │ sparkline│ │ sparkline│ │ sparkline│ │ bar    │ │
│  └──────────┘ └──────────┘ └──────────┘ └────────┘ │
│                                                     │
│  ┌──────────────────────┐  ┌────────────────────┐  │
│  │ Temperatures         │  │ Battery Health     │  │
│  │ CPU: 52°C  GPU: 48°C │  │ 91% capacity       │  │
│  │ Fan: 1800 RPM        │  │ Cycle count: 124   │  │
│  └──────────────────────┘  └────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Data Sources
| Metric | API | Notes |
|---|---|---|
| CPU usage | `host_processor_info` (Mach) | Per-core aggregated |
| RAM usage | `host_statistics64` (Mach) | Used / wired / compressed |
| GPU usage | `IOServiceMatching("IOAccelerator")` | IOKit |
| CPU temp | IOKit SMC key `TC0P` | Optional — nil on some hardware |
| GPU temp | IOKit SMC key `TG0P` | Optional |
| Fan speed | IOKit SMC key `F0Ac` | RPM |
| Disk space | `FileManager.volumeAvailableCapacityForImportantUsage` | |
| Battery | IOKit `AppleSmartBattery` service | |

### Performance Score (0–100)
Computed every 5 seconds from:
- RAM pressure: 30%
- CPU headroom: 25%
- Disk free %: 25%
- Thermal safety: 20%

Color coding: Green 80–100, Amber 50–79, Red 0–49

### Update Cadence
| Data | Interval | Reason |
|---|---|---|
| CPU / RAM / GPU | 2 seconds | Real-time feel |
| Temps + fan | 5 seconds | Reduce IOKit overhead |
| Disk / battery | 30 seconds | Slow-changing |
| Performance score | 5 seconds | Aggregated from above |

All polling on background `DispatchQueue.global(qos: .utility)`, published to main thread via `MainActor`.

### Error Handling
- All IOKit/SMC reads return `Optional` — never force unwrap
- Missing data shows `—` in UI, not a crash or error banner
- Permission denied: `PermissionState` enum drives graceful "Grant Access" banner

---

## 6. Data Layer

### SystemMonitor (@Observable)
```swift
@Observable class SystemMonitor {
    var cpuUsage: Double         // 0.0–1.0
    var ramUsed: UInt64          // bytes
    var ramTotal: UInt64         // bytes
    var gpuUsage: Double         // 0.0–1.0
    var cpuTemp: Double?         // °C (nil if unavailable)
    var gpuTemp: Double?         // °C
    var fanSpeed: Int?           // RPM
    var diskUsed: UInt64         // bytes
    var diskTotal: UInt64        // bytes
    var batteryPercent: Int      // 0–100
    var batteryCycleCount: Int
    var batteryHealth: Double    // 0.0–1.0
    var cpuHistory: [Double]     // last 60 samples (2 min)
    var ramHistory: [Double]
    var gpuHistory: [Double]
    var performanceScore: Int    // 0–100 computed
}
```

### Persistence (UserDefaults only)
| Key | Type | Purpose |
|---|---|---|
| `hasCompletedOnboarding` | Bool | Show onboarding once |
| `colorSchemePreference` | String | "system" / "light" / "dark" |
| `lastOptimizedDate` | Date | Phase 2 stub |

---

## 7. GitHub Actions CI/CD

```yaml
# .github/workflows/build.yml
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
      - name: Build
        run: |
          xcodebuild -scheme OulyMacTweaks \
                     -configuration Release \
                     -derivedDataPath build/
      - name: Package .app
        run: |
          cp -R build/Build/Products/Release/OulyMacTweaks.app .
          zip -r OulyMacTweaks.zip OulyMacTweaks.app
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: OulyMacTweaks
          path: OulyMacTweaks.zip
          retention-days: 7
```

---

## 8. Out of Scope for Phase 1
- One-click optimization engine (Phase 2)
- Gaming Mode (Phase 3)
- Software Manager (Phase 4)
- AI recommendations + licensing (Phase 5)
- Code signing, notarization, DMG installer (Phase 6)
- Menu bar status icon (Phase 2)
- Network calls of any kind
- Database / CoreData

---

## 9. Phase Roadmap (Summary)
| Phase | Deliverable |
|---|---|
| 1 (this) | App shell, branding, monitoring dashboard, snow background, onboarding |
| 2 | One-click optimization engine, RAM purge, cache cleanup, startup items |
| 3 | Gaming Mode, Game Mode API, FPS boost, background task reduction |
| 4 | Software Manager, app uninstaller, duplicate finder |
| 5 | AI recommendations, licensing/Pro tier, upgrade flows |
| 6 | Code signing, notarization, DMG installer, App Store assets, marketing |
