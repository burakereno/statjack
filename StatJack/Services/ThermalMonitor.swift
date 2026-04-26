import Foundation
import Observation

struct ThermalReading: Equatable {
    let average: Double
    let peak: Double
    let count: Int
}

@Observable
final class ThermalMonitor {
    var reading: ThermalReading?

    func apply(_ value: ThermalReading?) {
        reading = value
    }

    static func sample() -> ThermalReading? {
        let readings = StatJackReadTemperatureSensors().map { $0.doubleValue }
        guard !readings.isEmpty else { return nil }
        let avg = readings.reduce(0, +) / Double(readings.count)
        let peak = readings.max() ?? 0
        return ThermalReading(average: avg, peak: peak, count: readings.count)
    }
}
