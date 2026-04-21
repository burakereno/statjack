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

    // MARK: - Update

    func update() {
        let currentTimestamp = CFAbsoluteTimeGetCurrent()
        let (totalIn, totalOut) = getInterfaceBytes()

        if let prev = previousSnapshot {
            let deltaIn = totalIn >= prev.bytesIn ? totalIn - prev.bytesIn : 0
            let deltaOut = totalOut >= prev.bytesOut ? totalOut - prev.bytesOut : 0
            let deltaTime = currentTimestamp - prev.timestamp

            if deltaTime > 0 {
                networkUsage = NetworkUsage(
                    uploadSpeed: Double(deltaOut) / deltaTime,
                    downloadSpeed: Double(deltaIn) / deltaTime,
                    totalUploaded: totalOut,
                    totalDownloaded: totalIn
                )
            }
        }

        previousSnapshot = (totalIn, totalOut, currentTimestamp)
    }

    // MARK: - getifaddrs

    /// Returns total (bytesIn, bytesOut) across all non-loopback interfaces
    private func getInterfaceBytes() -> (UInt64, UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            let addr = current.pointee

            // Only look at AF_LINK (link-layer) addresses
            if let sa = addr.ifa_addr, sa.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: addr.ifa_name)

                // Skip loopback
                if name != "lo0", let data = addr.ifa_data {
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
