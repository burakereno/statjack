import AppKit
import SwiftUI

enum StatJackPopoverLayout {
    static let width: CGFloat = 320
    static let initialHeight: CGFloat = 860
    static let minimumHeight: CGFloat = 240
    static let screenEdgeMargin: CGFloat = 24

    static func clampedHeight(_ preferredHeight: CGFloat, visibleScreenHeight: CGFloat) -> CGFloat {
        let maximumHeight = max(minimumHeight, visibleScreenHeight - screenEdgeMargin)
        return min(max(preferredHeight, minimumHeight), maximumHeight)
    }
}

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
    private var dockBadgeView: DockBadgeView?
    private var preferredPopoverHeight = StatJackPopoverLayout.initialHeight
    private let statusImageRenderer = MenuBarStatusImageRenderer()

    private let activeInterval: TimeInterval = 2.0

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
        popover.contentSize = NSSize(
            width: StatJackPopoverLayout.width,
            height: StatJackPopoverLayout.initialHeight
        )
        popover.contentViewController = NSHostingController(
            rootView: ContentView(
                monitor: monitor,
                onSettingsVisibilityChanged: { [weak self] visible in
                    self?.settingsVisibilityChanged(visible)
                },
                onPreferredHeightChange: { [weak self] height in
                    self?.updatePopoverHeight(height)
                }
            )
                .frame(width: StatJackPopoverLayout.width)
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
            applyPreferredPopoverHeight(for: button.window?.screen)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updateMonitoringMode()
            monitor.refreshNow()
            focusPopoverWindow()
            startEventMonitor()
            Task { await UpdateChecker.shared.checkForUpdates() }
        }
    }

    private func updatePopoverHeight(_ preferredHeight: CGFloat) {
        preferredPopoverHeight = preferredHeight
        applyPreferredPopoverHeight(for: statusItem.button?.window?.screen)
    }

    private func applyPreferredPopoverHeight(for screen: NSScreen?) {
        let visibleScreenHeight = screen?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? preferredPopoverHeight
        let height = StatJackPopoverLayout.clampedHeight(
            preferredPopoverHeight,
            visibleScreenHeight: visibleScreenHeight
        )

        guard abs(popover.contentSize.height - height) > 0.5 else { return }
        popover.contentSize = NSSize(width: StatJackPopoverLayout.width, height: height)
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

        let badgeView: DockBadgeView
        if let dockBadgeView {
            badgeView = dockBadgeView
            badgeView.label = label
        } else {
            badgeView = DockBadgeView(label: label)
            dockBadgeView = badgeView
        }

        NSApp.dockTile.badgeLabel = nil
        if NSApp.dockTile.contentView !== badgeView {
            NSApp.dockTile.contentView = badgeView
        }
        badgeView.needsDisplay = true
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
            let image = statusImageRenderer.image(for: segments)
            statusItem.length = image.size.width
            button.image = image
            button.needsDisplay = true
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

}

private final class DockBadgeView: NSView {
    var label: String

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
