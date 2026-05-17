# OulyMac Tweaks — Phase 2 Design Spec
**Date:** 2026-05-17
**Phase:** 2 of 6 — Optimization Engine + Menu Bar
**Status:** Approved

---

## 1. Overview

Phase 2 activates the Optimize tab with a scan-first optimization engine and adds a persistent menu bar status item. Target audience: professionals and Mac gamers who want a premium, data-forward tool — dark, sharp, purposeful. No emojis anywhere in the UI; SF Symbols only.

**Deliverables:**
- Scan-first optimize flow (scan → results → optimize)
- RAM purge via memory pressure technique (no sudo)
- User cache cleanup via FileManager
- Startup Items locked card (stub, ships functional in Phase 6)
- Menu bar gauge ring (22×22pt NSStatusItem)

---

## 2. Architecture

### New Files
```
OulyMacTweaks/
├── Core/
│   └── Optimization/
│       ├── OptimizationEngine.swift   # @Observable — state machine, orchestration
│       ├── RAMPurger.swift            # memory pressure purge, no sudo
│       └── CacheCleaner.swift         # FileManager ~/Library/Caches scanner + cleaner
├── Features/
│   └── Optimize/
│       ├── OptimizeView.swift         # replaces OptimizeStubView
│       ├── ScanResultCard.swift       # reusable result card (icon, title, size, status)
│       └── OptimizeButton.swift       # animated CTA button (idle / running / done states)
└── App/
    └── AppDelegate.swift              # NSApplicationDelegate, NSStatusItem lifecycle
```

### Modified Files
- `OulyMacTweaks/App/OulyMacTweaksApp.swift` — add `@NSApplicationDelegateAdaptor`
- `OulyMacTweaks/Navigation/ContentView.swift` — inject `OptimizationEngine` via environment

### Technology
| Concern | Solution |
|---|---|
| RAM purge | `vm_allocate` / `vm_deallocate` to apply memory pressure, force OS to reclaim inactive pages |
| Cache scan | `FileManager.default.allocatedSizeOfDirectory(at:)` on `~/Library/Caches` |
| Cache clean | `FileManager.default.removeItem(at:)` per item in `~/Library/Caches` |
| Menu bar | `NSStatusBar.system.statusItem(withLength: NSSquareStatusItemLength)` |
| Menu bar drawing | Custom `NSView` subclass drawing `NSBezierPath` ring, no SwiftUI |
| State management | `@Observable OptimizationEngine` injected alongside `SystemMonitor` |

---

## 3. OptimizationEngine State Machine

```swift
@Observable final class OptimizationEngine {
    enum State {
        case idle
        case scanning
        case results(ram: UInt64, cache: UInt64)   // bytes available to free
        case optimizing
        case done(freed: UInt64)                    // total bytes freed
    }
    var state: State = .idle
    var lastOptimizedDate: Date? = nil
}
```

Transitions:
- `idle` → `scanning` (user taps Scan)
- `scanning` → `results` (scan completes, ~1–2 sec)
- `results` → `optimizing` (user taps Optimize Now)
- `optimizing` → `done` (all tasks complete)
- `done` → `idle` (user taps Scan Again)

---

## 4. RAM Purger

**Technique:** Allocate a large `vm_allocate` buffer (up to 80% of free physical RAM), write to every page to force macOS to compress inactive pages and push them out, then `vm_deallocate` immediately. This is the same approach used by Memory Clean and CleanMyMac. No `sudo`, no shell subprocess, no admin dialog.

```swift
struct RAMPurger {
    /// Returns bytes freed (estimated as inactive RAM before purge).
    func purge() -> UInt64
}
```

The scan phase reads `vm_statistics64.inactive_count * vm_page_size` to estimate how many bytes can be freed. This number is shown in the result card before the user commits.

---

## 5. Cache Cleaner

Operates on `~/Library/Caches` only — no system caches (those require root and ship in Phase 6).

```swift
struct CacheCleaner {
    /// Returns total bytes that would be freed (for the result card).
    func scan() -> UInt64

    /// Deletes contents and returns bytes actually freed.
    func clean() -> UInt64
}
```

`scan()` walks `~/Library/Caches` with `FileManager` and sums allocated file sizes. `clean()` removes each top-level item inside the directory (not the directory itself — macOS recreates items as needed). Items that fail to delete (locked files, SIP-protected paths) are silently skipped; the returned byte count reflects what was actually freed.

---

## 6. Optimize Tab UI

### Visual Language
- Background: deep navy via SnowBackgroundView (inherited from Phase 1)
- Cards: `.regularMaterial` frosted glass, 12pt corners, `0.5pt` inner border at 8% white opacity
- Accent colors: Brand Blue (`#2F80ED`) for scan/primary, Brand Purple (`#7B61FF`) for Optimize CTA
- Typography: SF Pro, numbers in `.largeTitle.weight(.bold)`, labels in `.footnote.secondary`
- Animations: `easeOut(duration: 0.18)` for all transitions — fast, decisive, not bouncy
- No emojis — SF Symbols only

### States

**Idle**
```
┌─────────────────────────────────────────┐
│                                         │
│         [  memorychip SF icon 48pt  ]   │
│         Scan your Mac                   │
│   See what's slowing you down           │
│                                         │
│         ┌──────────────────┐            │
│         │   Scan Now       │            │  ← pulsing blue glow (2s loop)
│         └──────────────────┘            │
│                                         │
└─────────────────────────────────────────┘
```

**Scanning**
- Scan button replaced by a spinning `ProgressView` (`.circular`, blue tint)
- Label: "Scanning…"
- Duration: reads RAM stats + walks cache directory, completes in ~1–2 seconds

**Results**
```
┌──────────────────────────────────────┐
│  memorychip   RAM Pressure           │
│               4.8 GB can be freed    │  ← inactive RAM estimate
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│  trash.fill   User Caches            │
│               2.3 GB found           │  ← ~/Library/Caches size
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│  lock.fill    Startup Items          │
│               Available after signing│  ← disabled, 40% opacity
└──────────────────────────────────────┘

         ┌─────────────────────┐
         │   Optimize Now      │         ← Brand Purple, full width
         └─────────────────────┘
```
Cards slide up with `easeOut(duration: 0.18)` staggered by 60ms each.

**Optimizing**
- Optimize Now button shows `ProgressView` inline, label becomes "Optimizing…"
- Cards remain visible (no layout shift)
- Both active cards show a subtle shimmer animation on their backgrounds

**Done**
```
┌──────────────────────────────────────┐
│  checkmark.circle.fill  RAM          │
│  (green)               3.9 GB freed  │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│  checkmark.circle.fill  Caches       │
│  (green)               2.1 GB freed  │
└──────────────────────────────────────┘

         Total freed: 6.0 GB
         ↑ largeTitle.bold, Brand Blue

         ┌─────────────────────┐
         │   Scan Again        │         ← resets to idle
         └─────────────────────┘
```
`lastOptimizedDate` written to `UserDefaults` here — dashboard "Last optimized" timestamp now shows a real value.

---

## 7. Menu Bar

### Implementation
`AppDelegate` conforms to `NSApplicationDelegate`. Added to `OulyMacTweaksApp` via `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`.

`NSStatusItem` created with `NSSquareStatusItemLength` (22×22pt). The button's view is a custom `NSView` subclass (`MenuBarGaugeView`) that draws directly with `NSBezierPath` — no SwiftUI, no SpriteKit.

### MenuBarGaugeView Drawing
- Background ring: thin circle, 15% white opacity
- Foreground arc: trimmed by score fraction, color-coded (green/amber/red matching score thresholds)
- Score number: drawn as `NSAttributedString` centered in ring, 9pt SF Rounded bold
- `needsDisplay = true` triggered every 5 seconds from a `Timer` observing `SystemMonitor.performanceScore`

### Click Behavior
Single click on status item → `NSApp.activate(ignoringOtherApps: true)` + bring main window front. No popover, no menu. Instant focus.

### Lifecycle
Status item created in `applicationDidFinishLaunching`. Destroyed automatically when app quits. `AppDelegate` holds a strong reference to `NSStatusItem` to prevent deallocation.

---

## 8. UserDefaults Keys (additions)

| Key | Type | Purpose |
|---|---|---|
| `lastOptimizedDate` | Double (TimeInterval) | Already defined in Phase 1 — written here for the first time |

No new persistence keys needed.

---

## 9. Error Handling

- Cache items that fail to delete: silently skip, count what succeeded
- RAM purge: if `vm_allocate` fails (extremely low memory), return 0 bytes freed gracefully
- Menu bar: if `NSStatusBar.system.statusItem` fails, log and continue — app still works without it
- All errors surface as graceful UI states (0 bytes freed card), never crashes

---

## 10. Out of Scope for Phase 2
- Startup items management (Phase 6 — requires signed binary)
- System cache cleanup (Phase 6 — requires root)
- Optimization history / log
- Scheduled auto-optimization
- Network calls of any kind
