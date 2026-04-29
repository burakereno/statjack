import Foundation
import Observation

@Observable
final class DiskMonitor {
    private(set) var diskUsage = DiskUsage(total: 0, available: 0)

    static func sample() -> DiskUsage? {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])

            guard let total = values.volumeTotalCapacity else { return nil }
            let available = values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)

            return DiskUsage(
                total: UInt64(max(total, 0)),
                available: UInt64(max(available, 0))
            )
        } catch {
            return nil
        }
    }

    func apply(_ usage: DiskUsage) {
        diskUsage = usage
    }
}
