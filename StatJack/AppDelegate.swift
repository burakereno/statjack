import AppKit
import SwiftUI

/// AppDelegate managing NSStatusItem + NSPopover for full menu bar control
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var monitor: SystemMonitor!
    private var eventMonitor: Any?
    private var lastMenuBarState: MenuBarState?

    private let idleInterval: TimeInterval = 5.0
    private let activeInterval: TimeInterval = 2.0

    private struct MenuBarState: Equatable {
        let iconOnly: Bool
        let showCPU: Bool
        let showRAM: Bool
        let showNetwork: Bool
        let title: String
    }

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

    @objc private func settingsChanged() {
        updateMonitoringMode()
        monitor.refreshNow()
        updateMenuBarButton()
    }

    @objc private func valuesChanged() { updateMenuBarButton() }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            monitor.startMonitoring(interval: activeInterval, collectAllMetrics: true)
            monitor.refreshNow()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            button.highlight(true)
            NSApp.activate(ignoringOtherApps: true)
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
        updateMonitoringMode()
        monitor.refreshNow()
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

    private func updateMonitoringMode() {
        monitor.startMonitoring(
            interval: popover.isShown ? activeInterval : idleInterval,
            collectAllMetrics: popover.isShown
        )
    }

    // MARK: - Update Menu Bar

    func updateMenuBarButton() {
        performMenuBarUpdate()
    }

    @MainActor
    private func performMenuBarUpdate() {
        guard let button = statusItem.button else { return }

        let settings = AppSettings.shared
        let showIconOnly = settings.iconOnly
            || (!settings.showCPU && !settings.showRAM && !settings.showNetwork)

        var segments: [String] = []
        if settings.showCPU { segments.append(monitor.menuBarCPU) }
        if settings.showRAM { segments.append(monitor.menuBarRAM) }
        if settings.showNetwork { segments.append(monitor.menuBarNet) }
        let title = showIconOnly ? "" : segments.joined(separator: "  ")
        let state = MenuBarState(
            iconOnly: showIconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showNetwork: settings.showNetwork,
            title: title
        )

        guard state != lastMenuBarState else { return }
        lastMenuBarState = state

        if showIconOnly || title.isEmpty {
            button.image = NSImage(systemSymbolName: AppIcons.app,
                                   accessibilityDescription: "StatJack")
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            let image = renderStatusImage(text: title)
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    /// Draw text into a template NSImage suitable for the menu bar.
    /// Always produces a valid image — never returns nil.
    private func renderStatusImage(text: String) -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let w = ceil(textSize.width) + 6
        let h: CGFloat = 20

        let image = NSImage(size: NSSize(width: w, height: h))
        image.lockFocus()
        let drawRect = NSRect(x: 3,
                              y: (h - textSize.height) / 2,
                              width: textSize.width,
                              height: textSize.height)
        (text as NSString).draw(in: drawRect, withAttributes: attrs)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
