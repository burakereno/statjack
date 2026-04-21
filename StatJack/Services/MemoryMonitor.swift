import Foundation
import Darwin
import Observation

/// Monitors system-wide memory usage via host_statistics64. Per-process
/// memory scanning was removed for the same reason as CPU: the repeated
/// PID walks were dominating our own CPU cost, and Activity Monitor
/// already serves that use case.
@Observable
final class MemoryMonitor {
    private(set) var memoryUsage = MemoryUsage(total: 0, used: 0, active: 0, wired: 0, compressed: 0, free: 0)

    private let totalMemory: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    private let pageSize: UInt64 = UInt64(vm_kernel_page_size)

    func update() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let used = active + wired + compressed

        memoryUsage = MemoryUsage(
            total: totalMemory,
            used: used,
            active: active,
            wired: wired,
            compressed: compressed,
            free: free
        )
    }
}
