import Foundation
import Observation

/// Central monitoring engine that orchestrates the remaining sub-monitors
/// (CPU, memory, network). The polling cadence is driven externally by the
/// AppDelegate so it can slow down when the popover is closed.
@Observable
final class SystemMonitor {
    let cpuMonitor = CPUMonitor()
    let memoryMonitor = MemoryMonitor()
    let networkMonitor = NetworkMonitor()

    /// Uptime in seconds since boot
    var uptime: TimeInterval = 0

    /// Individual menu bar display values
    var menuBarCPU: String = "0%"
    var menuBarRAM: String = "0%"
    var menuBarNet: String = "↑0K ↓0K"

    @ObservationIgnored
    private var timer: Timer?
    @ObservationIgnored
    private var currentInterval: TimeInterval = 0
    @ObservationIgnored
    private var collectAllMetrics = false
    @ObservationIgnored
    private var isUpdating = false
    @ObservationIgnored
    private var pendingRefresh = false
    @ObservationIgnored
    private let sampleQueue = DispatchQueue(label: "com.statjack.monitor.samples", qos: .utility)
    @ObservationIgnored
    private let bootDate: Date?

    init() {
        bootDate = Self.loadBootDate()
        tick()
        startMonitoring(interval: 5.0)
    }

    deinit {
        timer?.invalidate()
    }

    /// Starts (or reschedules) the repeating update timer at the given
    /// interval. Callers pass a slower interval when the popover is closed
    /// and a faster one while it's open.
    func startMonitoring(interval: TimeInterval, collectAllMetrics: Bool = false) {
        guard currentInterval != interval
            || self.collectAllMetrics != collectAllMetrics
            || timer == nil else { return }
        currentInterval = interval
        self.collectAllMetrics = collectAllMetrics

        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        currentInterval = 0
        pendingRefresh = false
    }

    func refreshNow() {
        tick()
    }

    /// One monitoring tick. Heavy work (the three Mach/sysctl calls) is kept
    /// off the main thread; observed properties are written back on main.
    private func tick() {
        guard !isUpdating else {
            pendingRefresh = true
            return
        }
        isUpdating = true

        let selection = metricSelection()
        guard selection.cpu || selection.memory || selection.network else {
            updateUptime()
            isUpdating = false
            runPendingRefreshIfNeeded()
            return
        }

        sampleQueue.async { [weak self] in
            let sample = SystemSample(
                cpu: selection.cpu ? CPUMonitor.sample() : nil,
                memory: selection.memory ? MemoryMonitor.sample() : nil,
                network: selection.network ? NetworkMonitor.sample() : nil
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.apply(sample)
                self.isUpdating = false
                NotificationCenter.default.post(name: .statJackValuesChanged, object: self)
                self.runPendingRefreshIfNeeded()
            }
        }
    }

    private func runPendingRefreshIfNeeded() {
        guard pendingRefresh else { return }
        pendingRefresh = false
        tick()
    }

    private func metricSelection() -> (cpu: Bool, memory: Bool, network: Bool) {
        guard !collectAllMetrics else { return (true, true, true) }

        let settings = AppSettings.shared
        let needsDockCPU = settings.showDockIcon && settings.showDockBadge
        guard !settings.iconOnly else { return (needsDockCPU, false, false) }
        return (settings.showCPU || needsDockCPU, settings.showRAM, settings.showNetwork)
    }

    private func apply(_ sample: SystemSample) {
        if let cpu = sample.cpu {
            cpuMonitor.apply(cpu)
            menuBarCPU = "\(Int(cpuMonitor.totalUsage))%"
        }

        if let memory = sample.memory {
            memoryMonitor.apply(memory)
            menuBarRAM = "\(Int(memoryMonitor.memoryUsage.usedPercentage))%"
        }

        if let network = sample.network {
            networkMonitor.apply(network)
            let up = Formatters.formatSpeedCompact(networkMonitor.networkUsage.uploadSpeed)
            let down = Formatters.formatSpeedCompact(networkMonitor.networkUsage.downloadSpeed)
            menuBarNet = "↑\(up) ↓\(down)"
        }

        updateUptime()
    }

    private func updateUptime() {
        guard let bootDate else { return }
        uptime = Date().timeIntervalSince(bootDate)
    }

    private static func loadBootDate() -> Date? {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 {
            return Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
        }
        return nil
    }
}

extension Notification.Name {
    /// Posted on the main thread whenever a monitoring tick has updated the
    /// menu-bar-visible values. AppDelegate listens for this so it can
    /// re-render the status item exactly once per change.
    static let statJackValuesChanged = Notification.Name("StatJackValuesChanged")
}
