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
