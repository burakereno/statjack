import AppKit
import SwiftUI

/// SwiftUI view rendered into the menu bar. Shares the exact same layout as
/// the live Preview in SettingsView, so the two always stay visually in sync.
private struct MenuBarContent: View {
    let iconOnly: Bool
    let showCPU: Bool
    let showRAM: Bool
    let showNetwork: Bool
    let cpu: String
    let ram: String
    let net: String

    var body: some View {
        if iconOnly || (!showCPU && !showRAM && !showNetwork) {
            Image(systemName: AppIcons.app)
                .font(.system(size: 13))
        } else {
            HStack(spacing: 8) {
                if showCPU {
                    HStack(spacing: 3) {
                        Image(systemName: AppIcons.cpu).font(.system(size: 10))
                        Text(cpu).font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
                if showRAM {
                    HStack(spacing: 3) {
                        Image(systemName: AppIcons.ram).font(.system(size: 10))
                        Text(ram).font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
                if showNetwork {
                    HStack(spacing: 3) {
                        Image(systemName: AppIcons.network).font(.system(size: 10))
                        Text(net).font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
            }
        }
    }
}

/// Cache key summarising every input that affects the rendered menu bar
/// image. Two ticks with the same key produce pixel-identical output, so we
/// can skip the SwiftUI render entirely on the second one.
private struct MenuBarCacheKey: Equatable {
    let iconOnly: Bool
    let showCPU: Bool
    let showRAM: Bool
    let showNetwork: Bool
    let cpu: String
    let ram: String
    let net: String
    let scale: CGFloat
}

/// AppDelegate managing NSStatusItem + NSPopover for full menu bar control
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var monitor: SystemMonitor!
    private var eventMonitor: Any?

    /// Last rendered menu-bar image keyed by its inputs. If the next tick
    /// produces the same key we reuse the cached NSImage instead of running
    /// SwiftUI's ImageRenderer again — this is the main reason the app now
    /// sits near 0% CPU when values are stable.
    private var lastRender: (key: MenuBarCacheKey, image: NSImage)?

    /// Polling cadence when the popover is closed vs. open. Menu bar text
    /// doesn't need sub-second freshness, but the popover feels laggy if we
    /// only tick every 5s while the user is watching.
    private let idleInterval: TimeInterval = 5.0
    private let activeInterval: TimeInterval = 2.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor = SystemMonitor()

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 320, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(monitor: monitor)
                .frame(width: 320, height: 560)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            updateMenuBarButton()
        }

        // Re-render the status item whenever the monitor produces new values
        // or the user toggles a visibility setting. Both paths are cheap
        // because the render itself is cache-gated.
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(settingsChanged),
                           name: .statJackSettingsChanged, object: nil)
        center.addObserver(self, selector: #selector(valuesChanged),
                           name: .statJackValuesChanged, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        monitor?.stopMonitoring()
    }

    @objc private func settingsChanged() { updateMenuBarButton() }
    @objc private func valuesChanged() { updateMenuBarButton() }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            monitor.startMonitoring(interval: activeInterval)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Highlight the menu bar button while popover is open
            button.highlight(true)
            // Activate so popover gets keyboard focus
            NSApp.activate(ignoringOtherApps: true)
            // Monitor clicks outside to close
            startEventMonitor()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        statusItem.button?.highlight(false)
        stopEventMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
        stopEventMonitor()
        monitor.startMonitoring(interval: idleInterval)
    }

    // MARK: - Event Monitor (close on outside click)

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Update Menu Bar

    /// Renders the menu-bar content via SwiftUI's ImageRenderer, but only when
    /// the inputs have actually changed. Pixel-perfect parity with the Preview
    /// in SettingsView, and a no-op in the common case where values are stable.
    func updateMenuBarButton() {
        MainActor.assumeIsolated {
            performMenuBarUpdate()
        }
    }

    @MainActor
    private func performMenuBarUpdate() {
        guard let button = statusItem.button else { return }

        let settings = AppSettings.shared
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let key = MenuBarCacheKey(
            iconOnly: settings.iconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showNetwork: settings.showNetwork,
            cpu: monitor.menuBarCPU,
            ram: monitor.menuBarRAM,
            net: monitor.menuBarNet,
            scale: scale
        )

        if let cached = lastRender, cached.key == key, button.image === cached.image {
            return
        }

        let content = MenuBarContent(
            iconOnly: settings.iconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showNetwork: settings.showNetwork,
            cpu: monitor.menuBarCPU,
            ram: monitor.menuBarRAM,
            net: monitor.menuBarNet
        )
        .foregroundStyle(Color.black)
        .padding(.horizontal, 2)
        .fixedSize()

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale

        if let rendered = renderer.nsImage {
            rendered.isTemplate = true
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.image = rendered
            lastRender = (key, rendered)
        } else if let icon = NSImage(systemSymbolName: AppIcons.app, accessibilityDescription: "StatJack") {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.image = icon
            lastRender = nil
        } else {
            button.image = nil
            button.title = "SJ"
            lastRender = nil
        }
    }
}
