# StatJack

<p align="center">
  <img src="https://statjack.burakerenoglu.com/apps/statjack/icon-rounded-20261030.webp" alt="StatJack" width="340">
</p>

**Lightweight macOS menu bar system monitor.** Track CPU, RAM, Disk, and Network usage at a glance — right from your menu bar.

<p align="center">
  <a href="https://github.com/burakereno/statjack/releases/latest/download/StatJack.dmg">
    <img src="https://img.shields.io/badge/Download-StatJack.dmg-22c55e?style=for-the-badge&logo=apple&logoColor=white&cb=2" alt="Download StatJack.dmg" height="48">
  </a>
  &nbsp;
  <a href="https://github.com/burakereno/statjack/releases/latest">
    <img src="https://img.shields.io/github/v/release/burakereno/statjack?style=for-the-badge&label=Latest&color=2563eb&cb=2" alt="Latest release" height="48">
  </a>
  &nbsp;
  <a href="https://openai.com/codex">
    <img src="https://img.shields.io/badge/Built%20with-Codex-2f80ed?style=for-the-badge&logo=openai&logoColor=white" alt="Built with Codex" height="48">
  </a>
</p>

<p align="center">
  <sub>macOS 14.0+ · ~3 MB · Developer ID signed and notarized</sub>
</p>

## Features

- 📊 **CPU** — total usage with user/system split
- 🧠 **Memory** — used/total RAM with active / wired / compressed breakdown
- 💾 **Disk** — show usage, whole free gigabytes, or both in the menu bar. Free space excludes purgeable files; disk alerts use the same measurement
- 🌐 **Network** — live upload/download speeds and session totals across network interface changes
- 🎮 **GPU** — utilization via IOAccelerator
- 🌡️ **Thermal state** — public macOS thermal pressure status (normal, elevated, high, critical)
- 📈 **Sparklines** — compact trend lines for live metrics
- 🔔 **Threshold alerts** — macOS notifications when CPU, RAM, or disk usage reaches your chosen percentage
- 🚀 **Launch at Login** — system Login Items via SMAppService
- ⬇️ **One-click in-app updates** — checks GitHub releases, downloads + installs the new DMG without leaving the app
- ⚡ **Minimal resource usage** — polling stops when the panel is closed and no metric or alert needs it
- 🖥️ **Native macOS** — SwiftUI + AppKit, runs as a menu bar app

## Screenshots

<p align="center">
  <img src="docs/dashboard.png" alt="Dashboard with CPU, Memory, Disk and Network cards" width="320">
  &nbsp;&nbsp;
  <img src="docs/settings.png" alt="Settings with menu bar toggles and Dock controls" width="320">
</p>

<p align="center">
  <sub>Compact trend lines · GPU + thermal state · Dock badge metric picker · threshold notifications.</sub>
</p>

## Installation

### Download DMG

1. Go to the [Releases](../../releases/latest) page
2. Download **`StatJack.dmg`**
3. Open the DMG and drag **StatJack.app** to your **Applications** folder

Double-click StatJack to launch it. The app is Developer ID signed and notarized, and will appear in your menu bar (not in the Dock).

## Build from Source

### Requirements

- macOS 14.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Steps

```bash
# Clone the repo
git clone https://github.com/burakereno/statjack.git
cd statjack

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project StatJack.xcodeproj -scheme StatJack -configuration Release build
```

## Tech Stack

- **SwiftUI** — UI framework
- **AppKit** — NSStatusItem, NSPopover, event monitoring
- **Mach/sysctl** — CPU & memory stats via kernel APIs
- **NET_RT_IFLIST2** — 64-bit network counters for each active interface
- **XcodeGen** — Project file generation

## License

MIT License — see [LICENSE](LICENSE) for details.
