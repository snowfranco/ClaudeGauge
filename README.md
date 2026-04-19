# Claude Gauge 🟢

A tiny macOS floating widget that shows your Claude.ai session usage at a glance.

## What It Does

- Floats in the corner of your screen, always visible
- Color-coded dot shows your usage level instantly
- Hover to expand: see % used, status, time estimates, and tips
- Auto-polls claude.ai every 60 seconds (configurable)
- Manual slider for testing/demo without a cookie

## Color Guide

| Color | Range | Meaning |
|-------|-------|---------|
| 🟢 Green | 0–39% | Work freely |
| 🟡 Yellow | 40–69% | Consider starting a new conversation |
| 🟠 Orange | 70–84% | Switch to Sonnet, wrap up |
| 🔴 Red | 85–100% | Start fresh now or wait for recovery |

## Setup

### 1. Open in Xcode
```
open ClaudeGauge.xcodeproj
```

### 2. Set your Team
In Xcode → Target → Signing & Capabilities → set your Apple Developer Team (free account works).

### 3. Build & Run
Press ⌘R. The widget appears in the bottom-right corner.

### 4. Connect Live Data (optional but recommended)
To get real usage data from claude.ai:

1. Open claude.ai in Chrome/Safari and log in
2. Open DevTools: ⌘ + Option + I
3. Go to Application → Cookies → https://claude.ai
4. Find `sessionKey` and copy its Value
5. In Claude Gauge: hover the widget → click ⚙ → paste cookie → Save & Connect

The widget will now auto-update every 60 seconds with your real usage.

### 5. Test Without a Cookie
Use the Manual Override slider in Settings to preview all color states.

## Project Structure

```
ClaudeGauge/
├── ClaudeGaugeApp.swift      # App entry point
├── AppDelegate.swift         # Window + menu bar setup
├── UsageStore.swift          # Data model, polling, API calls
├── FloatingWidgetView.swift  # Compact pill + expanded hover view
├── SettingsView.swift        # Cookie input, slider, color legend
├── Extensions.swift          # Color(hex:) utility
└── Info.plist                # App config, network permissions
```

## Notes

- **LSUIElement = true** means the app has no Dock icon (menu bar only)
- The session cookie is stored in UserDefaults locally — never transmitted anywhere except to claude.ai
- The cookie expires when you log out of claude.ai — just paste a fresh one if it stops working
- Network sandbox is disabled to allow direct requests to claude.ai

## Coming Next (Phase 2+)

- [ ] Sound notifications at custom thresholds
- [ ] "Time until recovery" countdown
- [ ] Usage history graph (7 days)
- [ ] Best time of day recommendations
- [ ] One-click "Start fresh conversation"
