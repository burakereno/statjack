import Foundation
import Darwin
import Observation

/// Monitors overall CPU usage using host_processor_info. Per-process CPU
/// accounting was removed intentionally: the repeated libproc scans across
/// every PID were the dominant source of CPU overhead in this app, and
/// Activity Monitor already covers the per-process use case.
@Observable
@MainActor
final class CPUMonitor {
    /// Overall CPU usage percentage (0-100)
    private(set) var totalUsage: Double = 0

    /// User CPU percentage
    private(set) var userUsage: Double = 0

    /// System CPU percentage
    private(set) var systemUsage: Double = 0

    /// Previous CPU ticks for delta calculation
    @ObservationIgnored
    private var previous: CPUSample?

    nonisolated static func sample() -> CPUSample? {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return nil }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let cores = (0..<Int(numCPUs)).map { i in
            let offset = Int(CPU_STATE_MAX) * i
            return CPUSample.Ticks(
                user: UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: cpuInfo[offset + Int(CPU_STATE_NICE)])
            )
        }
        return CPUSample(cores: cores)
    }

    func apply(_ sample: CPUSample) {
        defer { previous = sample }
        guard let previous, previous.cores.count == sample.cores.count else { return }
        var user: UInt64 = 0, system: UInt64 = 0, idle: UInt64 = 0
        for (old, new) in zip(previous.cores, sample.cores) {
            // Mach ticks wrap independently on each core and in each state.
            user += UInt64(new.user &- old.user) + UInt64(new.nice &- old.nice)
            system += UInt64(new.system &- old.system)
            idle += UInt64(new.idle &- old.idle)
        }
        let total = user + system + idle
        guard total > 0 else { return }
        userUsage = Double(user) / Double(total) * 100
        systemUsage = Double(system) / Double(total) * 100
        totalUsage = userUsage + systemUsage
    }
}
