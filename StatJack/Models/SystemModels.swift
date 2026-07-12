import Foundation

/// System-wide memory breakdown
struct MemoryUsage: Equatable, Sendable {
    let total: UInt64       // Total physical memory
    let used: UInt64        // App-like anonymous + wired + compressed memory
    let app: UInt64
    let wired: UInt64
    let compressed: UInt64
    let free: UInt64

    static func calculated(
        total: UInt64,
        pageSize: UInt64,
        internalPages: UInt64,
        purgeablePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        freePages: UInt64
    ) -> MemoryUsage {
        let appPages = internalPages >= purgeablePages
            ? internalPages - purgeablePages
            : 0
        let app = appPages * pageSize
        let wired = wiredPages * pageSize
        let compressed = compressedPages * pageSize
        let componentTotal = app.addingReportingOverflow(wired)
        let appAndWired = componentTotal.overflow ? UInt64.max : componentTotal.partialValue
        let usedTotal = appAndWired.addingReportingOverflow(compressed)
        let used = min(total, usedTotal.overflow ? UInt64.max : usedTotal.partialValue)

        return MemoryUsage(
            total: total,
            used: used,
            app: app,
            wired: wired,
            compressed: compressed,
            free: min(total, freePages * pageSize)
        )
    }

    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

/// Root filesystem usage
struct DiskUsage: Equatable, Sendable {
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
struct NetworkUsage: Equatable, Sendable {
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
struct CPUSample: Equatable, Sendable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

/// Raw network counters sampled off the main thread, then applied on main.
struct NetworkSample: Equatable, Sendable {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let timestamp: TimeInterval
}

/// Optional samples collected during one monitoring tick.
struct SystemSample: Sendable {
    let cpu: CPUSample?
    let memory: MemoryUsage?
    let disk: DiskUsage?
    let diskSampled: Bool
    let network: NetworkSample?
    let gpuUtilization: Double?
    let gpuSampled: Bool
    let thermal: ThermalCondition?
    let thermalSampled: Bool
}
