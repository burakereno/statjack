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
}
