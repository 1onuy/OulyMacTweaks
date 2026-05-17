# OulyMac Tweaks — Phase 3 Design Spec
**Date:** 2026-05-17
**Phase:** 3 of 6 — Gaming Mode
**Status:** Approved

---

## 1. Overview

Phase 3 activates the Gaming tab with a one-tap Gaming Mode that kills background processes and disables system services to free up CPU/GPU/RAM for the active game. Auto-detects game launches via NSWorkspace observation. Shows live performance stats while active. Same premium dark aesthetic as Phases 1–2 — SF Symbols only, no emojis.

**Deliverables:**
- `GamingModeEngine` — `@Observable` state machine (idle / active)
- `ProcessKiller` — smart high-impact process detection + user-customizable kill list
- `ServiceManager` — no-sudo disable of Spotlight, Time Machine, notifications
- `GameDetector` — NSWorkspace observer, fullscreen + CPU spike heuristic
- `GamingView` — full UI (idle config + active live stats)
- `GamingProcessCard` — reusable process row card
- `GamingStatsBar` — live CPU/GPU/RAM gauges (reuses SystemMonitor data)

---

## 2. Architecture

### New Files
```
OulyMacTweaks/
├── Core/
│   └── Gaming/
│       ├── GamingModeEngine.swift   # @Observable state machine
│       ├── ProcessKiller.swift      # smart process scan + termination
│       ├── ServiceManager.swift     # Spotlight / Time Machine / notifications
│       └── GameDetector.swift       # NSWorkspace game launch observer
└── Features/
    └── Gaming/
        ├── GamingView.swift         # full tab UI
        ├── GamingProcessCard.swift  # reusable process row
        └── GamingStatsBar.swift     # live stat gauges
```

### Modified Files
- `OulyMacTweaks/App/OulyMacTweaksApp.swift` — inject `GamingModeEngine` via environment
- `OulyMacTweaks/Navigation/ContentView.swift` — swap `GamingStubView` for `GamingView`

### Technology
| Concern | Solution |
|---|---|
| Process list | `NSWorkspace.shared.runningApplications` |
| App termination | `NSRunningApplication.terminate()` → `forceTerminate()` fallback after 2s |
| Spotlight disable | `Process` runs `mdutil -d /` |
| Time Machine pause | `Process` runs `tmutil stopbackup` |
| Notification suppress | `NSDistributedNotificationCenter` posts `com.apple.notificationcenterui.dndstart` |
| Game detection | `NSWorkspace.shared.notificationCenter` + fullscreen + CPU spike heuristic |
| State management | `@Observable GamingModeEngine` injected via SwiftUI environment |
| Kill list persistence | `UserDefaults` (user-toggled state survives restarts) |

---

## 3. GamingModeEngine State Machine

```swift
@Observable final class GamingModeEngine {
    enum State {
        case idle
        case active(killedCount: Int)
    }
    var state: State = .idle
    var killList: [KillTarget] = []
    var autoDetectEnabled: Bool = true
    var disableSpotlight: Bool = true
    var pauseTimeMachine: Bool = true
    var suppressNotifications: Bool = true
}

struct KillTarget: Identifiable, Codable {
    let id: UUID
    let name: String
    let bundleID: String?
    let isUserAdded: Bool     // true = manually added by user
    var isEnabled: Bool       // user can toggle individual items off
}
```

**Transitions:**
- `idle` → `active` — user taps "Activate Gaming Mode" OR `GameDetector` fires and `autoDetectEnabled` is true
- `active` → `idle` — user taps "Deactivate"

**On activation:** `ProcessKiller` terminates all enabled `KillTarget`s, `ServiceManager` disables selected system services.

**On deactivation:** Nothing is restarted. Killed processes and disabled services stay off. User restarts them manually.

---

## 4. ProcessKiller

```swift
protocol ProcessKilling {
    func scanHighImpact() -> [KillTarget]
    func kill(targets: [KillTarget]) -> Int   // returns count actually killed
}

struct MockProcessKiller: ProcessKilling { ... }
struct ProcessKiller: ProcessKilling { ... }
```

**`scanHighImpact()`:** Reads `NSWorkspace.shared.runningApplications`, filters to `.regular` activation policy only (excludes system agents). Ranks by CPU usage + memory. Returns apps above threshold: **> 5% CPU** or **> 100 MB RAM**, excluding OulyMac Tweaks itself.

**`kill(targets:)`:** For each enabled target, calls `NSRunningApplication.terminate()`. If the app is still running after 2 seconds, calls `forceTerminate()`. Returns count of successfully terminated apps.

**Persistence:** `killList` is encoded to `UserDefaults` (key: `"gamingKillList"`). User-added targets survive restarts. Smart-detected targets are refreshed each time the view appears.

---

## 5. ServiceManager

```swift
protocol ServiceManaging {
    func disableSpotlight()
    func pauseTimeMachine()
    func suppressNotifications()
}

struct MockServiceManager: ServiceManaging { ... }
struct ServiceManager: ServiceManaging { ... }
```

Each method is fire-and-forget. Failures are silently ignored (services may already be off or unavailable). No sudo required for any operation.

| Method | Implementation |
|---|---|
| `disableSpotlight()` | `Process`: `/usr/bin/mdutil -d /` |
| `pauseTimeMachine()` | `Process`: `/usr/bin/tmutil stopbackup` |
| `suppressNotifications()` | Post `com.apple.notificationcenterui.dndstart` via `NSDistributedNotificationCenter` |

---

## 6. GameDetector

```swift
protocol GameDetecting {
    func startWatching(onGameDetected: @escaping () -> Void)
    func stopWatching()
}

struct GameDetector: GameDetecting { ... }
```

Listens to `NSWorkspace.shared.notificationCenter` for `NSWorkspace.didActivateApplicationNotification`. On each activation, checks two heuristics:

1. **Fullscreen** — app's `NSRunningApplication.activationPolicy == .regular` and the frontmost app's presentation options include `.fullScreen`
2. **CPU spike** — `SystemMonitor.cpuUsage > 40` within 5 seconds of app launch

Both signals together trigger `onGameDetected`. Single signal alone is ignored (too many false positives). `GameDetector` is started in `GamingModeEngine.startDetecting()` and stopped when Gaming Mode goes active or the view disappears.

---

## 7. Gaming Tab UI

### Visual Language
- Same as Phase 2: deep navy background via `SnowBackgroundView`, `.regularMaterial` frosted glass cards, 12pt corners, `0.5pt` inner border at 8% white opacity
- Accent: `AppColors.brandBlue` for activate button, `AppColors.danger` for deactivate
- SF Symbols only — no emojis

### Idle State

```
┌─────────────────────────────────────┐
│  Settings                           │
│  ┌───────────────────────────────┐  │
│  │ gamecontroller  Auto-detect   │  │
│  │ games                [toggle] │  │
│  │ magnifyingglass Spotlight     │  │
│  │ indexing             [toggle] │  │
│  │ clock  Time Machine  [toggle] │  │
│  │ bell.slash  Notifications     │  │
│  │                      [toggle] │  │
│  └───────────────────────────────┘  │
│                                     │
│  Processes to Kill                  │
│  ┌───────────────────────────────┐  │
│  │ Chrome    850MB  45%  [toggle]│  │
│  │ Dropbox   120MB   8%  [toggle]│  │
│  │ Slack      95MB   3%  [toggle]│  │
│  └───────────────────────────────┘  │
│  [+ Add process]                    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    Activate Gaming Mode     │    │  ← brandBlue glow pulse
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### Active State

```
┌─────────────────────────────────────┐
│  GAMING MODE ACTIVE                 │
│  7 processes killed                 │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ CPU  ████████░░  74%          │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ GPU  ██████░░░░  58%          │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ RAM  █████░░░░░  6.2 / 16 GB  │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │       Deactivate            │    │  ← AppColors.danger
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

---

## 8. UserDefaults Keys (additions)

| Key | Type | Purpose |
|---|---|---|
| `gamingKillList` | Data (JSON) | Persisted `[KillTarget]` — user's customized kill list |
| `gamingAutoDetect` | Bool | Auto-detect game launches setting |
| `gamingDisableSpotlight` | Bool | Spotlight toggle preference |
| `gamingPauseTimeMachine` | Bool | Time Machine toggle preference |
| `gamingSuppressNotifications` | Bool | Notifications toggle preference |

---

## 9. Error Handling

- Apps that fail to terminate: silently skip, count is reduced accordingly
- `mdutil` / `tmutil` failures: silently ignore — services may already be stopped
- `GameDetector` workspace observation failure: log and continue — manual activation still works
- All errors surface as graceful UI states, never crashes

---

## 10. Out of Scope for Phase 3

- Re-launching killed processes on deactivation (user choice — manual restart)
- FPS overlay or in-game HUD
- Per-game profiles / presets
- Network throttling for background apps
- GPU priority APIs (macOS does not expose these without private entitlements)
