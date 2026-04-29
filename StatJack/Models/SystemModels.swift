import Foundation

/// System-wide memory breakdown
struct MemoryUsage {
    let total: UInt64       // Total physical memory
    let used: UInt64        // Used memory (active + wired + compressed)
    let active: UInt64
    let wired: UInt64
    let compressed: UInt64
    let free: UInt64

    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

/// Root filesystem usage
struct DiskUsage {
    let total: UInt64
    let available: UInt64

    var used: UInt64 {
        total > available ? total - available : 0
    }

    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

/// System-wide network throughput
struct NetworkUsage {
    let uploadSpeed: Double    // bytes per second
    let downloadSpeed: Double  // bytes per second
    let totalUploaded: UInt64  // cumulative bytes
    let totalDownloaded: UInt64

    var uploadFormatted: String {
        Formatters.formatBytesPerSecond(uploadSpeed)
    }

    var downloadFormatted: String {
        Formatters.formatBytesPerSecond(downloadSpeed)
    }
}

/// Raw CPU counters sampled off the main thread, then applied on main.
struct CPUSample {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

/// Raw network counters sampled off the main thread, then applied on main.
struct NetworkSample {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let timestamp: TimeInterval
}

/// Optional samples collected during one monitoring tick.
struct SystemSample {
    let cpu: CPUSample?
    let memory: MemoryUsage?
    let disk: DiskUsage?
    let diskSampled: Bool
    let network: NetworkSample?
    let gpuUtilization: Double?
    let gpuSampled: Bool
    let thermal: ThermalReading?
    let thermalSampled: Bool
}
