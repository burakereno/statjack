import Foundation
import Testing
@testable import StatJack

struct ThermalConditionTests {
    @Test
    func mapsEveryPublicProcessThermalState() {
        #expect(ThermalCondition(processInfoState: .nominal) == .nominal)
        #expect(ThermalCondition(processInfoState: .fair) == .fair)
        #expect(ThermalCondition(processInfoState: .serious) == .serious)
        #expect(ThermalCondition(processInfoState: .critical) == .critical)
    }

    @Test
    func exposesStableCompactLabelsAndLevels() {
        #expect(ThermalCondition.nominal.compactLabel == "OK")
        #expect(ThermalCondition.fair.compactLabel == "FAIR")
        #expect(ThermalCondition.serious.compactLabel == "HIGH")
        #expect(ThermalCondition.critical.compactLabel == "CRIT")
        #expect(ThermalCondition.allCases.map(\.level) == [0, 33, 67, 100])
    }
}
