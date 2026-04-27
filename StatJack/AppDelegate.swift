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
    private var currentActivationPolicy: NSApplication.ActivationPolicy?

    private let idleInterval: TimeInterval = 5.0
    private let activeInterval: TimeInterval = 2.0

    private struct MenuBarState: Equatable {
        let iconOnly: Bool
        let showCPU: Bool
        let showRAM: Bool
        let showNetwork: Bool
        let segments: [MenuBarMetricSegment]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = SystemMonitor()
        applyActivationPolicy()

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(monitor: monitor)
                .frame(width: 320, height: 440)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            updateMenuBarButton()
        }
        NSApp.dockTile.badgeLabel = nil

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(settingsChanged),
                           name: .statJackSettingsChanged, object: nil)
        center.addObserver(self, selector: #selector(valuesChanged),
                           name: .statJackValuesChanged, object: nil)

        UpdateChecker.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        monitor?.stopMonitoring()
    }

    @objc private func settingsChanged() {
        applyActivationPolicy()
        updateMonitoringMode()
        monitor.refreshNow()
        updateMenuBarButton()
    }

    @objc private func valuesChanged() {
        updateMenuBarButton()
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            monitor.startMonitoring(interval: activeInterval, collectAllMetrics: true)
            monitor.refreshNow()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            focusPopoverWindow()
            startEventMonitor()
            Task { await UpdateChecker.shared.checkForUpdates() }
        }
    }

    private func focusPopoverWindow() {
        Task { @MainActor [weak self] in
            guard let self, self.popover.isShown else { return }
            self.popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
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

    private func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = AppSettings.shared.showDockIcon ? .regular : .accessory
        guard currentActivationPolicy != policy else { return }

        NSApp.setActivationPolicy(policy)
        currentActivationPolicy = policy

        if policy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Update Menu Bar

    func updateMenuBarButton() {
        performMenuBarUpdate()
    }

    @MainActor
    private func performMenuBarUpdate() {
        guard let button = statusItem.button else { return }

        let settings = AppSettings.shared
        let showIconOnly = MenuBarDisplay.showIconOnly(
            iconOnly: settings.iconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showNetwork: settings.showNetwork,
            showGPU: settings.showGPU,
            showTemperature: settings.showTemperature
        )
        let segments = MenuBarDisplay.metricSegments(
            iconOnly: settings.iconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showNetwork: settings.showNetwork,
            showGPU: settings.showGPU,
            showTemperature: settings.showTemperature,
            cpu: monitor.menuBarCPU,
            ram: monitor.menuBarRAM,
            net: monitor.menuBarNet,
            gpu: monitor.menuBarGPU,
            temp: monitor.menuBarTemp
        )
        let state = MenuBarState(
            iconOnly: showIconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showNetwork: settings.showNetwork,
            segments: segments
        )

        guard state != lastMenuBarState else { return }
        lastMenuBarState = state

        if showIconOnly || segments.isEmpty {
            statusItem.length = NSStatusItem.squareLength
            button.image = NSImage(systemSymbolName: AppIcons.app,
                                   accessibilityDescription: "StatJack")
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            let image = renderStatusImage(segments: segments)
            statusItem.length = image.size.width
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    /// Draws the same fixed-width icon + value segments used by the settings
    /// preview, preventing the status item from resizing on every network tick.
    private func renderStatusImage(segments: [MenuBarMetricSegment]) -> NSImage {
        let w = MenuBarDisplay.contentWidth(for: segments)
        let h = MenuBarDisplay.statusHeight
        let font = NSFont.monospacedSystemFont(
            ofSize: MenuBarDisplay.metricTextPointSize,
            weight: .medium
        )
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        let image = NSImage(size: NSSize(width: w, height: h))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()

        var x = MenuBarDisplay.horizontalPadding
        for segment in segments {
            drawSymbol(segment.symbolName, x: x, canvasHeight: h)

            let textX = x + MenuBarDisplay.metricIconWidth + MenuBarDisplay.iconTextSpacing
            let textSize = (segment.text as NSString).size(withAttributes: attrs)
            let textY = floor((h - textSize.height) / 2)
            (segment.text as NSString).draw(
                at: NSPoint(x: textX, y: textY),
                withAttributes: attrs
            )
            x += segment.width + MenuBarDisplay.segmentSpacing
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func drawSymbol(_ symbolName: String, x: CGFloat, canvasHeight: CGFloat) {
        let config = NSImage.SymbolConfiguration(
            pointSize: MenuBarDisplay.metricIconPointSize,
            weight: .medium
        )
        guard let symbol = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config) else { return }

        let symbolSize = symbol.size
        let rect = NSRect(
            x: x + (MenuBarDisplay.metricIconWidth - symbolSize.width) / 2,
            y: (canvasHeight - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        symbol.draw(in: rect)
    }
}
