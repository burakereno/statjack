# StatJack

<p align="center">
  <img src="statjack.png" alt="StatJack" width="340" height="340">
</p>

**Lightweight macOS menu bar system monitor.** Track CPU, RAM, and Network usage at a glance — right from your menu bar.

<p align="center">
  <a href="https://github.com/burakereno/statjack/releases/latest/download/StatJack.dmg">
    <img src="https://img.shields.io/badge/Download-StatJack.dmg-22c55e?style=for-the-badge&logo=apple&logoColor=white&cb=2" alt="Download StatJack.dmg" height="48">
  </a>
  &nbsp;
  <a href="https://github.com/burakereno/statjack/releases/latest">
    <img src="https://img.shields.io/github/v/release/burakereno/statjack?style=for-the-badge&label=Latest&color=2563eb&cb=2" alt="Latest release" height="48">
  </a>
</p>

<p align="center">
  <sub>macOS 14.0+ · ~3 MB · See <a href="#installation">Installation</a> for first-launch instructions</sub>
</p>

## Features

- 📊 **CPU** — total usage with user/system split
- 🧠 **Memory** — used/total RAM with active / wired / compressed breakdown
- 🌐 **Network** — live upload/download speeds + session totals
- 🎮 **GPU** — utilization via IOAccelerator
- 🌡️ **Temperature** — average + peak across all SoC sensors (Apple Silicon)
- 📈 **Sparklines** — last 60 samples drawn under every metric
- 🔔 **Threshold alerts** — macOS notifications when CPU or RAM cross your set %
- 🌍 **Public IP** — fetched once at launch, click to copy
- 🚀 **Launch at Login** — system Login Items via SMAppService
- ⬇️ **One-click in-app updates** — checks GitHub releases, downloads + installs the new DMG without leaving the app
- ⚡ **Minimal resource usage** — adaptive polling, hidden metrics skipped while idle
- 🖥️ **Native macOS** — SwiftUI + AppKit, runs as a menu bar app

## Screenshots

<p align="center">
  <img src="docs/dashboard.png" alt="Dashboard with Public IP, CPU, Memory and Network" width="320">
  &nbsp;&nbsp;
  <img src="docs/extras.png" alt="GPU and Temperature cards with sparklines" width="320">
</p>

<p align="center">
  <img src="docs/alerts.png" alt="Threshold alerts and About card with the in-app update button" width="320">
</p>

<p align="center">
  <sub>CPU / Memory / Network with live sparklines · GPU + temperature for Apple Silicon · per-metric threshold notifications and one-click in-app updates.</sub>
</p>

## Installation

### Download DMG

1. Go to the [Releases](../../releases/latest) page
2. Download **`StatJack.dmg`**
3. Open the DMG and drag **StatJack.app** to your **Applications** folder

### Important: First Launch (Unsigned App)

Since StatJack is not notarized by Apple, macOS will block it on first launch. To fix this, run the following command in Terminal **once** after installing:

```bash
xattr -cr /Applications/StatJack.app
```

Then double-click StatJack to launch it. The app will appear in your menu bar (not in the Dock).

> **Note:** This command removes the quarantine flag that macOS applies to downloaded apps. It's a standard procedure for open-source macOS apps that aren't distributed through the App Store.

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
- **getifaddrs** — Network throughput monitoring
- **XcodeGen** — Project file generation

## License

MIT License — see [LICENSE](LICENSE) for details.
