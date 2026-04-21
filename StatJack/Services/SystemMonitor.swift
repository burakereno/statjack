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

    init() {
        // Do an initial synchronous update so the menu bar has real values
        // on the first paint instead of the placeholder "0%".
        tick()
        startMonitoring(interval: 5.0)
    }

    deinit {
        timer?.invalidate()
    }

    /// Starts (or reschedules) the repeating update timer at the given
    /// interval. Callers pass a slower interval when the popover is closed
    /// and a faster one while it's open.
    func startMonitoring(interval: TimeInterval) {
        guard currentInterval != interval || timer == nil else { return }
        currentInterval = interval

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
    }

    /// One monitoring tick. Heavy work (the three Mach/sysctl calls) is kept
    /// off the main thread; observed properties are written back on main.
    private func tick() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            self.cpuMonitor.update()
            self.memoryMonitor.update()
            self.networkMonitor.update()

            let cpuText = "\(Int(self.cpuMonitor.totalUsage))%"
            let ramText = "\(Int(self.memoryMonitor.memoryUsage.usedPercentage))%"
            let up = Formatters.formatSpeedCompact(self.networkMonitor.networkUsage.uploadSpeed)
            let down = Formatters.formatSpeedCompact(self.networkMonitor.networkUsage.downloadSpeed)
            let netText = "↑\(up) ↓\(down)"

            DispatchQueue.main.async {
                self.updateUptime()
                self.menuBarCPU = cpuText
                self.menuBarRAM = ramText
                self.menuBarNet = netText
                NotificationCenter.default.post(name: .statJackValuesChanged, object: self)
            }
        }
    }

    private func updateUptime() {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 {
            let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
            uptime = Date().timeIntervalSince(bootDate)
        }
    }
}

extension Notification.Name {
    /// Posted on the main thread whenever a monitoring tick has updated the
    /// menu-bar-visible values. AppDelegate listens for this so it can
    /// re-render the status item exactly once per change.
    static let statJackValuesChanged = Notification.Name("StatJackValuesChanged")
}
