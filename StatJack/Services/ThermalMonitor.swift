import Foundation
import Observation

enum ThermalCondition: Int, CaseIterable, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical

    nonisolated init(processInfoState: ProcessInfo.ThermalState) {
        switch processInfoState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .critical
        }
    }

    var title: String {
        switch self {
        case .nominal: "Normal"
        case .fair: "Elevated"
        case .serious: "High"
        case .critical: "Critical"
        }
    }

    var compactLabel: String {
        switch self {
        case .nominal: "OK"
        case .fair: "FAIR"
        case .serious: "HIGH"
        case .critical: "CRIT"
        }
    }

    var level: Double {
        switch self {
        case .nominal: 0
        case .fair: 33
        case .serious: 67
        case .critical: 100
        }
    }

    var impact: String {
        switch self {
        case .nominal: "No thermal impact"
        case .fair: "Slightly elevated"
        case .serious: "Performance may reduce"
        case .critical: "Cooling required"
        }
    }
}

@Observable
@MainActor
final class ThermalMonitor {
    private(set) var condition: ThermalCondition = .nominal

    func apply(_ value: ThermalCondition) {
        condition = value
    }

    nonisolated static func sample() -> ThermalCondition {
        ThermalCondition(processInfoState: ProcessInfo.processInfo.thermalState)
    }
}
