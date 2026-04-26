import Foundation
import IOKit
import Observation

@Observable
final class GPUMonitor {
    /// Latest device utilization 0–100. `nil` until first sample lands.
    var utilization: Double?

    func apply(_ value: Double?) {
        utilization = value
    }

    /// Reads "Device Utilization %" off the IOAccelerator service. Cheap
    /// — single registry query, no IOServiceOpen, no continuous handle.
    static func sample() -> Double? {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard let cfStats = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            if let util = cfStats["Device Utilization %"] as? NSNumber {
                return util.doubleValue
            }
            if let util = cfStats["GPU Activity(%)"] as? NSNumber {
                return util.doubleValue
            }
        }

        return nil
    }
}
