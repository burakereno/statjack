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
    private var isSettingsVisible = false
    private var lastDockBadgeLabel: String?
    private var isDockBadgeVisible = false
    private var statusSymbolCache: [String: NSImage] = [:]

    private let activeInterval: TimeInterval = 2.0
    private let statusSymbolConfig = NSImage.SymbolConfiguration(
        pointSize: MenuBarDisplay.metricIconPointSize,
        weight: .medium
    )
    private let statusFont = NSFont.monospacedSystemFont(
        ofSize: MenuBarDisplay.metricTextPointSize,
        weight: .medium
    )

    private struct MenuBarState: Equatable {
        let iconOnly: Bool
        let showCPU: Bool
        let showRAM: Bool
        let showDisk: Bool
        let showNetwork: Bool
        let segments: [MenuBarMetricSegment]
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = SystemMonitor()
        applyActivationPolicy()

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 320, height: 572)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(
                monitor: monitor,
                onSettingsVisibilityChanged: { [weak self] visible in
                    self?.settingsVisibilityChanged(visible)
                }
            )
                .frame(width: 320, height: 572)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            updateMenuBarButton()
        }
        updateDockBadge()

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
        updateDockBadge()
    }

    @objc private func valuesChanged() {
        updateMenuBarButton()
        updateDockBadge()
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updateMonitoringMode()
            monitor.refreshNow()
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

    private func settingsVisibilityChanged(_ visible: Bool) {
        guard isSettingsVisible != visible else { return }
        isSettingsVisible = visible
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
        let useActiveMonitoring = popover.isShown && !isSettingsVisible
        monitor.startMonitoring(
            interval: useActiveMonitoring ? activeInterval : AppSettings.shared.menuBarRefreshInterval.rawValue,
            collectAllMetrics: useActiveMonitoring
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

    private func updateDockBadge() {
        let settings = AppSettings.shared
        guard settings.showDockIcon, settings.showDockBadge else {
            guard isDockBadgeVisible || lastDockBadgeLabel != nil else { return }
            NSApp.dockTile.badgeLabel = nil
            NSApp.dockTile.contentView = nil
            lastDockBadgeLabel = nil
            isDockBadgeVisible = false
            return
        }

        let label = dockBadgeLabel(for: settings.dockBadgeMetric)
        guard !isDockBadgeVisible || lastDockBadgeLabel != label else { return }
        lastDockBadgeLabel = label
        isDockBadgeVisible = true

        NSApp.dockTile.badgeLabel = nil
        NSApp.dockTile.contentView = DockBadgeView(label: label)
        NSApp.dockTile.display()
    }

    private func dockBadgeLabel(for metric: DockBadgeMetric) -> String {
        switch metric {
        case .cpu:
            monitor.menuBarCPU
        case .ram:
            monitor.menuBarRAM
        case .temperature:
            monitor.menuBarTemp
        case .gpu:
            monitor.menuBarGPU
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
            showDisk: settings.showDisk,
            showNetwork: settings.showNetwork,
            showGPU: settings.showGPU,
            showTemperature: settings.showTemperature
        )
        let segments = MenuBarDisplay.metricSegments(
            iconOnly: settings.iconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showDisk: settings.showDisk,
            showNetwork: settings.showNetwork,
            showGPU: settings.showGPU,
            showTemperature: settings.showTemperature,
            cpu: monitor.menuBarCPU,
            ram: monitor.menuBarRAM,
            disk: monitor.menuBarDisk,
            net: monitor.menuBarNet,
            gpu: monitor.menuBarGPU,
            temp: monitor.menuBarTemp
        )
        let state = MenuBarState(
            iconOnly: showIconOnly,
            showCPU: settings.showCPU,
            showRAM: settings.showRAM,
            showDisk: settings.showDisk,
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
        let attrs: [NSAttributedString.Key: Any] = [
            .font: statusFont,
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
        let symbol: NSImage
        if let cached = statusSymbolCache[symbolName] {
            symbol = cached
        } else if let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(statusSymbolConfig) {
            statusSymbolCache[symbolName] = image
            symbol = image
        } else {
            return
        }

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

private final class DockBadgeView: NSView {
    private let label: String

    init(label: String) {
        self.label = label
        super.init(frame: NSRect(origin: .zero, size: NSApp.dockTile.size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds
        NSApp.applicationIconImage.draw(
            in: bounds,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let fontSize = max(18, bounds.height * 0.18)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let textSize = (label as NSString).size(withAttributes: attrs)
        let badgeHeight = max(bounds.height * 0.3, textSize.height + 10)
        let badgeWidth = max(badgeHeight, textSize.width + 20)
        let badgeRect = NSRect(
            x: bounds.maxX - badgeWidth - bounds.width * 0.03,
            y: bounds.maxY - badgeHeight - bounds.height * 0.02,
            width: badgeWidth,
            height: badgeHeight
        )

        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2).fill()

        let textRect = NSRect(
            x: badgeRect.minX,
            y: badgeRect.midY - textSize.height / 2,
            width: badgeRect.width,
            height: textSize.height
        )
        (label as NSString).draw(in: textRect, withAttributes: attrs)
    }
}
