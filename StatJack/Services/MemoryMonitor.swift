import Foundation
import Darwin
import Observation

/// Monitors system-wide memory usage via host_statistics64. Per-process
/// memory scanning was removed for the same reason as CPU: the repeated
/// PID walks were dominating our own CPU cost, and Activity Monitor
/// already serves that use case.
@Observable
@MainActor
final class MemoryMonitor {
    private(set) var memoryUsage = MemoryUsage(total: 0, used: 0, app: 0, wired: 0, compressed: 0, free: 0)

    nonisolated private static let totalMemory: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    nonisolated static func sample() -> MemoryUsage? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        var pageSize: vm_size_t = 0

        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        return MemoryUsage.calculated(
            total: Self.totalMemory,
            pageSize: UInt64(pageSize),
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count),
            freePages: UInt64(stats.free_count)
        )
    }

    func apply(_ usage: MemoryUsage) {
        memoryUsage = usage
    }
}
