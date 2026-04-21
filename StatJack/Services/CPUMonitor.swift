import Foundation
import Darwin
import Observation

/// Monitors overall CPU usage using host_processor_info. Per-process CPU
/// accounting was removed intentionally: the repeated libproc scans across
/// every PID were the dominant source of CPU overhead in this app, and
/// Activity Monitor already covers the per-process use case.
@Observable
final class CPUMonitor {
    /// Overall CPU usage percentage (0-100)
    private(set) var totalUsage: Double = 0

    /// User CPU percentage
    private(set) var userUsage: Double = 0

    /// System CPU percentage
    private(set) var systemUsage: Double = 0

    /// Previous CPU ticks for delta calculation
    @ObservationIgnored
    private var previousCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    func update() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(cpuInfo[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)])
        }

        if let prev = previousCPUTicks {
            let deltaUser = totalUser - prev.user
            let deltaSystem = totalSystem - prev.system
            let deltaIdle = totalIdle - prev.idle
            let deltaNice = totalNice - prev.nice
            let totalDelta = deltaUser + deltaSystem + deltaIdle + deltaNice

            if totalDelta > 0 {
                userUsage = Double(deltaUser + deltaNice) / Double(totalDelta) * 100
                systemUsage = Double(deltaSystem) / Double(totalDelta) * 100
                totalUsage = userUsage + systemUsage
            }
        }

        previousCPUTicks = (totalUser, totalSystem, totalIdle, totalNice)
    }
}
