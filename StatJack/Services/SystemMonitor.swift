import Foundation
import Observation
import UserNotifications

/// Central monitoring engine that orchestrates the remaining sub-monitors
/// (CPU, memory, network). The polling cadence is driven externally by the
/// AppDelegate so it can slow down when the popover is closed.
@Observable
@MainActor
final class SystemMonitor {
    private struct MetricSelection: Sendable {
        let cpu: Bool
        let memory: Bool
        let disk: Bool
        let network: Bool
        let gpu: Bool
        let thermal: Bool
    }

    let cpuMonitor = CPUMonitor()
    let memoryMonitor = MemoryMonitor()
    let diskMonitor = DiskMonitor()
    let networkMonitor = NetworkMonitor()
    let gpuMonitor = GPUMonitor()
    let thermalMonitor = ThermalMonitor()

    /// Uptime in seconds since boot
    var uptime: TimeInterval = 0

    /// Individual menu bar display values
    var menuBarCPU: String = "0%"
    var menuBarRAM: String = "0%"
    var menuBarDisk: String = "0%"
    var menuBarNet: String = "↑0K ↓0K"
    var menuBarGPU: String = "--"
    var menuBarTemp: String = "OK"

    /// Rolling history of recent samples for sparkline rendering.
    /// Capped at `historyCapacity` entries; appended on every tick.
    var cpuHistory: [Double] = []
    var ramHistory: [Double] = []
    var diskHistory: [Double] = []
    var netUploadHistory: [Double] = []
    var netDownloadHistory: [Double] = []
    var gpuHistory: [Double] = []
    var thermalHistory: [Double] = []

    @ObservationIgnored
    static let historyCapacity = 60

    @ObservationIgnored
    private var lastCPUAlert: Date?
    @ObservationIgnored
    private var lastRAMAlert: Date?
    @ObservationIgnored
    private var cpuAlertSnoozed = false
    @ObservationIgnored
    private var ramAlertSnoozed = false
    @ObservationIgnored
    private let alertCooldown: TimeInterval = 300
    @ObservationIgnored
    private let alertResetMargin: Double = 5

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
    private var lastThermalSample: Date?
    @ObservationIgnored
    private let thermalSampleInterval: TimeInterval = 15
    @ObservationIgnored
    private var lastDiskSample: Date?
    @ObservationIgnored
    private let diskSampleInterval: TimeInterval = 300
    @ObservationIgnored
    private var samplingTask: Task<Void, Never>?
    @ObservationIgnored
    private let bootDate: Date?

    init() {
        bootDate = Self.loadBootDate()
        tick()
        startMonitoring(interval: AppSettings.shared.menuBarRefreshInterval.rawValue)
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
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        currentInterval = 0
        pendingRefresh = false
        isUpdating = false
        samplingTask?.cancel()
        samplingTask = nil
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
        let sampleThermal = selection.thermal && shouldSampleThermal()
        let sampleDisk = selection.disk && shouldSampleDisk()
        guard selection.cpu || selection.memory || sampleDisk || selection.network || selection.gpu || sampleThermal else {
            updateUptime()
            isUpdating = false
            runPendingRefreshIfNeeded()
            return
        }

        samplingTask = Task { [weak self] in
            let sample = await Self.collectSample(
                selection: selection,
                sampleDisk: sampleDisk,
                sampleThermal: sampleThermal
            )
            guard !Task.isCancelled, let self else { return }

            self.samplingTask = nil
            self.apply(sample)
            self.isUpdating = false
            NotificationCenter.default.post(name: .statJackValuesChanged, object: self)
            self.runPendingRefreshIfNeeded()
        }
    }

    nonisolated private static func collectSample(
        selection: MetricSelection,
        sampleDisk: Bool,
        sampleThermal: Bool
    ) async -> SystemSample {
        SystemSample(
            cpu: selection.cpu ? CPUMonitor.sample() : nil,
            memory: selection.memory ? MemoryMonitor.sample() : nil,
            disk: sampleDisk ? DiskMonitor.sample() : nil,
            diskSampled: sampleDisk,
            network: selection.network ? NetworkMonitor.sample() : nil,
            gpuUtilization: selection.gpu ? GPUMonitor.sample() : nil,
            gpuSampled: selection.gpu,
            thermal: sampleThermal ? ThermalMonitor.sample() : nil,
            thermalSampled: sampleThermal
        )
    }

    private func runPendingRefreshIfNeeded() {
        guard pendingRefresh else { return }
        pendingRefresh = false
        tick()
    }

    private func shouldSampleThermal() -> Bool {
        let now = Date()
        if let lastThermalSample,
           now.timeIntervalSince(lastThermalSample) < thermalSampleInterval
        {
            return false
        }
        lastThermalSample = now
        return true
    }

    private func shouldSampleDisk() -> Bool {
        let now = Date()
        if let lastDiskSample,
           now.timeIntervalSince(lastDiskSample) < diskSampleInterval
        {
            return false
        }
        lastDiskSample = now
        return true
    }

    private func metricSelection() -> MetricSelection {
        guard !collectAllMetrics else {
            return MetricSelection(cpu: true, memory: true, disk: true, network: true, gpu: true, thermal: true)
        }

        let settings = AppSettings.shared
        let dockMetric = settings.showDockIcon && settings.showDockBadge ? settings.dockBadgeMetric : nil
        let needsDockCPU = dockMetric == .cpu
        let needsDockMemory = dockMetric == .ram
        let needsDockGPU = dockMetric == .gpu
        let needsDockTemperature = dockMetric == .temperature
        let needsCPU = (!settings.iconOnly && settings.showCPU) || settings.cpuAlertEnabled || needsDockCPU
        let needsMemory = (!settings.iconOnly && settings.showRAM) || settings.ramAlertEnabled || needsDockMemory
        let needsDisk = !settings.iconOnly && settings.showDisk
        let needsNetwork = !settings.iconOnly && settings.showNetwork
        let needsGPU = (!settings.iconOnly && settings.showGPU) || needsDockGPU
        let needsTemperature = (!settings.iconOnly && settings.showTemperature) || needsDockTemperature
        return MetricSelection(
            cpu: needsCPU,
            memory: needsMemory,
            disk: needsDisk,
            network: needsNetwork,
            gpu: needsGPU,
            thermal: needsTemperature
        )
    }

    private func apply(_ sample: SystemSample) {
        if let cpu = sample.cpu {
            cpuMonitor.apply(cpu)
            menuBarCPU = "\(Int(cpuMonitor.totalUsage))%"
            appendHistory(&cpuHistory, value: cpuMonitor.totalUsage)
            checkCPUAlert(cpuMonitor.totalUsage)
        }

        if let memory = sample.memory {
            memoryMonitor.apply(memory)
            menuBarRAM = "\(Int(memoryMonitor.memoryUsage.usedPercentage))%"
            appendHistory(&ramHistory, value: memoryMonitor.memoryUsage.usedPercentage)
            checkRAMAlert(memoryMonitor.memoryUsage.usedPercentage)
        }

        if sample.diskSampled, let disk = sample.disk {
            diskMonitor.apply(disk)
            menuBarDisk = "\(Int(diskMonitor.diskUsage.usedPercentage))%"
            appendHistory(&diskHistory, value: diskMonitor.diskUsage.usedPercentage)
        }

        if let network = sample.network {
            networkMonitor.apply(network)
            let up = Formatters.formatSpeedCompact(networkMonitor.networkUsage.uploadSpeed)
            let down = Formatters.formatSpeedCompact(networkMonitor.networkUsage.downloadSpeed)
            menuBarNet = "↑\(up) ↓\(down)"
            appendHistory(&netUploadHistory, value: networkMonitor.networkUsage.uploadSpeed)
            appendHistory(&netDownloadHistory, value: networkMonitor.networkUsage.downloadSpeed)
        }

        if sample.gpuSampled {
            gpuMonitor.apply(sample.gpuUtilization)
            if let g = sample.gpuUtilization {
                appendHistory(&gpuHistory, value: g)
                menuBarGPU = "\(Int(g))%"
            } else {
                menuBarGPU = "--"
            }
        }

        if sample.thermalSampled {
            if let condition = sample.thermal {
                thermalMonitor.apply(condition)
                appendHistory(&thermalHistory, value: condition.level)
                menuBarTemp = condition.compactLabel
            }
        }

        updateUptime()
    }

    private func appendHistory(_ history: inout [Double], value: Double) {
        history.append(value)
        if history.count > Self.historyCapacity {
            history.removeFirst(history.count - Self.historyCapacity)
        }
    }

    private func checkCPUAlert(_ value: Double) {
        let s = AppSettings.shared
        guard s.cpuAlertEnabled else {
            cpuAlertSnoozed = false
            return
        }
        if value < max(0, s.cpuAlertThreshold - alertResetMargin) {
            cpuAlertSnoozed = false
            return
        }
        guard value >= s.cpuAlertThreshold, !cpuAlertSnoozed else { return }
        if let last = lastCPUAlert, Date().timeIntervalSince(last) < alertCooldown { return }
        lastCPUAlert = Date()
        cpuAlertSnoozed = true
        Self.postAlert(
            title: "High CPU Usage",
            body: "CPU at \(Int(value))% (threshold \(Int(s.cpuAlertThreshold))%)"
        )
    }

    private func checkRAMAlert(_ value: Double) {
        let s = AppSettings.shared
        guard s.ramAlertEnabled else {
            ramAlertSnoozed = false
            return
        }
        if value < max(0, s.ramAlertThreshold - alertResetMargin) {
            ramAlertSnoozed = false
            return
        }
        guard value >= s.ramAlertThreshold, !ramAlertSnoozed else { return }
        if let last = lastRAMAlert, Date().timeIntervalSince(last) < alertCooldown { return }
        lastRAMAlert = Date()
        ramAlertSnoozed = true
        Self.postAlert(
            title: "High Memory Usage",
            body: "RAM at \(Int(value))% (threshold \(Int(s.ramAlertThreshold))%)"
        )
    }

    private static func postAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
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
