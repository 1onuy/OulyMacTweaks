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
