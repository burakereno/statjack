import Foundation
import Darwin
import Observation

/// Monitors system-wide network throughput using 64-bit routing interface statistics
@Observable
@MainActor
final class NetworkMonitor {
    /// Current network usage
    private(set) var networkUsage = NetworkUsage(
        uploadSpeed: 0, downloadSpeed: 0,
        totalUploaded: 0, totalDownloaded: 0
    )

    @ObservationIgnored
    private var previous: NetworkSample?

    func apply(_ sample: NetworkSample) {
        if let previous {
            let elapsed = sample.timestamp - previous.timestamp
            guard elapsed > 0 else { return }
            var received: UInt64 = 0, sent: UInt64 = 0
            for (id, current) in sample.interfaces {
                guard let old = previous.interfaces[id] else { continue }
                if current.bytesIn >= old.bytesIn { received += current.bytesIn - old.bytesIn }
                if current.bytesOut >= old.bytesOut { sent += current.bytesOut - old.bytesOut }
            }
            networkUsage = NetworkUsage(
                uploadSpeed: Double(sent) / elapsed, downloadSpeed: Double(received) / elapsed,
                totalUploaded: networkUsage.totalUploaded + sent,
                totalDownloaded: networkUsage.totalDownloaded + received
            )
        }
        previous = sample
    }

    nonisolated static func sample() -> NetworkSample? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        // The list can grow between the size query and the read.
        for _ in 0..<2 {
            var size = 0
            guard sysctl(&mib, 6, nil, &size, nil, 0) == 0, size > 0 else { return nil }
            var bytes = Data(count: size)
            let status = bytes.withUnsafeMutableBytes { ptr in
                sysctl(&mib, 6, ptr.baseAddress, &size, nil, 0)
            }
            if status != 0 {
                if errno == ENOMEM { continue }
                return nil
            }
            return bytes.withUnsafeBytes { raw in
                var offset = 0
                var counters: [String: InterfaceCounters] = [:]
                while offset < size {
                    guard size - offset >= 4 else { return nil }
                    let length = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                    guard length >= 4, length <= size - offset else { return nil }
                    defer { offset += length }
                    guard raw[offset + 2] == RTM_VERSION, raw[offset + 3] == RTM_IFINFO2 else { continue }
                    guard length >= MemoryLayout<if_msghdr2>.size else { return nil }
                    let msg = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let flags = msg.ifm_flags
                    guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
                          (flags & IFF_LOOPBACK) == 0 else { continue }
                    var buffer = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    guard if_indextoname(UInt32(msg.ifm_index), &buffer) != nil else { continue }
                    let name = String(cString: buffer)
                    guard !["awdl", "llw", "bridge", "utun"].contains(where: name.hasPrefix) else { continue }
                    counters["\(msg.ifm_index):\(name)"] = InterfaceCounters(
                        bytesIn: msg.ifm_data.ifi_ibytes, bytesOut: msg.ifm_data.ifi_obytes
                    )
                }
                return NetworkSample(interfaces: counters, timestamp: ProcessInfo.processInfo.systemUptime)
            }
        }
        return nil
    }
}
