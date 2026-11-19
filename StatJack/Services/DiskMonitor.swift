import Foundation
import Observation

@Observable
@MainActor
final class DiskMonitor {
    private(set) var diskUsage = DiskUsage(total: 0, available: 0)

    nonisolated static func sample() -> DiskUsage? {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey
            ])

            return measuredUsage(total: values.volumeTotalCapacity, free: values.volumeAvailableCapacity)
        } catch {
            return nil
        }
    }

    nonisolated static func measuredUsage(total: Int?, free: Int?) -> DiskUsage? {
        guard let total, total > 0, let free, (0...total).contains(free) else { return nil }
        return DiskUsage(total: UInt64(total), available: UInt64(free))
    }

    func apply(_ usage: DiskUsage) {
        diskUsage = usage
    }
}
