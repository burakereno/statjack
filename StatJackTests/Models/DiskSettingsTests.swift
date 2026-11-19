import Foundation
import Testing
@testable import StatJack

@MainActor
struct DiskSettingsTests {
    @Test
    func existingDiskPreferenceIsPreservedWithNewOptionsOff() throws {
        let suite = "StatJack.DiskSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "showDisk")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.showDisk)
        #expect(settings.showDiskFree == false)
        #expect(settings.diskAlertEnabled == false)
        #expect(settings.diskAlertThreshold == 90)
    }

    @Test
    func diskOptionsPersistIndependently() throws {
        let suite = "StatJack.DiskSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "diskAlertEnabled")
        let settings = AppSettings(defaults: defaults)

        #expect(settings.diskAlertEnabled)
        settings.showDisk = true
        settings.showDiskFree = true
        settings.diskAlertThreshold = 95
        settings.diskAlertEnabled = false
        let restored = AppSettings(defaults: defaults)

        #expect(restored.showDisk)
        #expect(restored.showDiskFree)
        #expect(restored.diskAlertThreshold == 95)
        #expect(restored.diskAlertEnabled == false)
    }

    @Test(arguments: [
        (false, false, false, false, false),
        (false, true, false, false, true),
        (false, false, true, false, true),
        (false, true, true, false, true),
        (false, false, false, true, true),
        (true, true, true, false, false),
        (true, false, false, true, true),
        (true, true, true, true, true)
    ])
    func monitoringFollowsDisplayAndAlertOptions(_ testCase: (Bool, Bool, Bool, Bool, Bool)) throws {
        let (iconOnly, showUsage, showFree, alertEnabled, expected) = testCase
        let suite = "StatJack.DiskSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(iconOnly, forKey: "iconOnly")
        defaults.set(showUsage, forKey: "showDisk")
        defaults.set(showFree, forKey: "showDiskFree")
        defaults.set(alertEnabled, forKey: "diskAlertEnabled")

        #expect(AppSettings(defaults: defaults).needsDiskMonitoring == expected)
    }

    @Test
    func idleIconDoesNotPollUntilAMetricIsNeeded() throws {
        let suite = "StatJack.IdleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "iconOnly")
        let settings = AppSettings(defaults: defaults)
        let monitor = SystemMonitor(settings: settings)
        defer { monitor.stopMonitoring() }
        #expect(monitor.isPolling == false)
        monitor.startMonitoring(interval: 2, collectAllMetrics: true)
        #expect(monitor.isPolling)
        monitor.startMonitoring(interval: 10)
        #expect(monitor.isPolling == false)
    }

    @Test
    func unknownDiskSpaceIsNotAFullDisk() {
        #expect(DiskMonitor.measuredUsage(total: 500, free: nil) == nil)
        #expect(DiskMonitor.measuredUsage(total: 0, free: 0) == nil)
        #expect(DiskMonitor.measuredUsage(total: 500, free: 0)?.usedPercentage == 100)
    }
}
