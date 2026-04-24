import Foundation
import Darwin
import Observation

/// Monitors system-wide network throughput using getifaddrs (public API)
@Observable
final class NetworkMonitor {
    /// Current network usage
    private(set) var networkUsage = NetworkUsage(
        uploadSpeed: 0, downloadSpeed: 0,
        totalUploaded: 0, totalDownloaded: 0
    )

    /// Previous snapshot for delta calculation
    @ObservationIgnored
    private var previousSnapshot: (bytesIn: UInt64, bytesOut: UInt64, timestamp: TimeInterval)?

    /// First usable counters in this process, for session totals.
    @ObservationIgnored
    private var baselineSnapshot: (bytesIn: UInt64, bytesOut: UInt64)?

    // MARK: - Update

    static func sample() -> NetworkSample {
        let (totalIn, totalOut) = getInterfaceBytes()
        return NetworkSample(
            bytesIn: totalIn,
            bytesOut: totalOut,
            timestamp: CFAbsoluteTimeGetCurrent()
        )
    }

    func apply(_ sample: NetworkSample) {
        if let prev = previousSnapshot {
            let deltaIn = sample.bytesIn >= prev.bytesIn ? sample.bytesIn - prev.bytesIn : 0
            let deltaOut = sample.bytesOut >= prev.bytesOut ? sample.bytesOut - prev.bytesOut : 0
            let deltaTime = sample.timestamp - prev.timestamp
            let baseline = baselineSnapshot ?? (prev.bytesIn, prev.bytesOut)
            baselineSnapshot = baseline

            if deltaTime > 0 {
                networkUsage = NetworkUsage(
                    uploadSpeed: Double(deltaOut) / deltaTime,
                    downloadSpeed: Double(deltaIn) / deltaTime,
                    totalUploaded: sample.bytesOut >= baseline.bytesOut ? sample.bytesOut - baseline.bytesOut : 0,
                    totalDownloaded: sample.bytesIn >= baseline.bytesIn ? sample.bytesIn - baseline.bytesIn : 0
                )
            }
        } else {
            baselineSnapshot = (sample.bytesIn, sample.bytesOut)
        }

        previousSnapshot = (sample.bytesIn, sample.bytesOut, sample.timestamp)
    }

    // MARK: - getifaddrs

    /// Returns total (bytesIn, bytesOut) across all non-loopback interfaces
    private static func getInterfaceBytes() -> (UInt64, UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            let addr = current.pointee

            if let sa = addr.ifa_addr, sa.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: addr.ifa_name)
                let flags = Int32(addr.ifa_flags)
                let isUsable = (flags & IFF_UP) != 0
                    && (flags & IFF_RUNNING) != 0
                    && (flags & IFF_LOOPBACK) == 0
                    && !name.hasPrefix("awdl")
                    && !name.hasPrefix("llw")
                    && !name.hasPrefix("bridge")
                    && !name.hasPrefix("utun")

                if isUsable, let data = addr.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self)
                    totalIn += UInt64(networkData.pointee.ifi_ibytes)
                    totalOut += UInt64(networkData.pointee.ifi_obytes)
                }
            }

            ptr = addr.ifa_next.flatMap { UnsafeMutablePointer($0) }
        }

        return (totalIn, totalOut)
    }
}
