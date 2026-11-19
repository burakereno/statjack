import Foundation
import Testing
@testable import StatJack

struct DiskAlertStateTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let highUsage = DiskUsage(total: 1_000, available: 100)
    private let recoveredUsage = DiskUsage(total: 1_000, available: 160)

    @Test
    func alertStartsAtThresholdAndDoesNotRepeatWhileDiskStaysFull() {
        var state = DiskAlertState()
        let firstAlert = state.shouldNotify(usage: highUsage, enabled: true, threshold: 90, now: start)
        #expect(firstAlert)
        #expect(state.shouldNotify(
            usage: highUsage, enabled: true, threshold: 90, now: start.addingTimeInterval(3_600)
        ) == false)
    }

    @Test
    func recoveryAndCooldownAreBothRequiredForAnotherAlert() {
        var state = DiskAlertState()
        let firstAlert = state.shouldNotify(usage: highUsage, enabled: true, threshold: 90, now: start)
        #expect(firstAlert)
        #expect(state.shouldNotify(
            usage: recoveredUsage, enabled: true, threshold: 90, now: start.addingTimeInterval(10)
        ) == false)
        #expect(state.shouldNotify(
            usage: highUsage, enabled: true, threshold: 90, now: start.addingTimeInterval(299)
        ) == false)
        let rearmedAlert = state.shouldNotify(
            usage: highUsage, enabled: true, threshold: 90, now: start.addingTimeInterval(300)
        )
        #expect(rearmedAlert)
    }

    @Test
    func smallDropsDoNotRearmTheAlert() {
        var state = DiskAlertState()
        let firstAlert = state.shouldNotify(usage: highUsage, enabled: true, threshold: 90, now: start)
        #expect(firstAlert)
        #expect(state.shouldNotify(
            usage: DiskUsage(total: 1_000, available: 150),
            enabled: true, threshold: 90, now: start.addingTimeInterval(300)
        ) == false)
        #expect(state.shouldNotify(
            usage: highUsage, enabled: true, threshold: 90, now: start.addingTimeInterval(301)
        ) == false)
    }

    @Test
    func disabledAlertClearsTheHighUsageEpisode() {
        var state = DiskAlertState()
        let firstAlert = state.shouldNotify(usage: highUsage, enabled: true, threshold: 90, now: start)
        #expect(firstAlert)
        #expect(state.shouldNotify(
            usage: highUsage, enabled: false, threshold: 90, now: start.addingTimeInterval(300)
        ) == false)
        let reenabledAlert = state.shouldNotify(
            usage: highUsage, enabled: true, threshold: 90, now: start.addingTimeInterval(301)
        )
        #expect(reenabledAlert)
    }

    @Test
    func belowThresholdAndUnknownCapacityDoNotAlert() {
        var state = DiskAlertState()
        #expect(state.shouldNotify(
            usage: DiskUsage(total: 1_000, available: 101), enabled: true, threshold: 90, now: start
        ) == false)
        #expect(state.shouldNotify(
            usage: DiskUsage(total: 0, available: 0), enabled: true, threshold: 0, now: start
        ) == false)
    }
}
