import Testing
@testable import StatJack

@MainActor
struct UsageAlertTests {
    @Test
    func waitsForPermissionAndRetriesUntilAccepted() async {
        let alert = UsageAlert()
        enum Refused: Error { case denied }
        var attempts = 0
        await alert.evaluate(value: 92, threshold: 90, authorized: false, now: 0) { attempts += 1 }
        #expect(attempts == 0)
        await alert.evaluate(value: 92, threshold: 90, authorized: true, now: 1) {
            attempts += 1
            throw Refused.denied
        }
        await alert.evaluate(value: 92, threshold: 90, authorized: true, now: 2) { attempts += 1 }
        await alert.evaluate(value: 92, threshold: 90, authorized: true, now: 3_602) { attempts += 1 }
        #expect(attempts == 2)
    }

    @Test(arguments: [(90.0, 84.0), (5.0, 0.0)])
    func rearmNeedsRecoveryAndCooldown(_ levels: (Double, Double)) async {
        let alert = UsageAlert()
        var count = 0
        for (level, time) in [(levels.0 - 1, 0.0), (levels.0, 1), (levels.0 - 1, 2),
                              (levels.0, 302), (levels.1, 303), (levels.0, 304)] {
            await alert.evaluate(value: level, threshold: levels.0, authorized: true, now: time) { count += 1 }
        }
        #expect(count == 2)
        await alert.evaluate(value: levels.1, threshold: levels.0, authorized: true, now: 305) { count += 1 }
        await alert.evaluate(value: levels.0, threshold: levels.0, authorized: true, now: 603) { count += 1 }
        #expect(count == 2)
        await alert.evaluate(value: levels.0, threshold: levels.0, authorized: true, now: 604) { count += 1 }
        #expect(count == 3)
    }

    @Test
    func disablingClearsHighEpisode() async {
        let alert = UsageAlert()
        var count = 0
        await alert.evaluate(value: 96, threshold: 90, authorized: true, now: 0) { count += 1 }
        alert.reset()
        await alert.evaluate(value: 96, threshold: 90, authorized: true, now: 600) { count += 1 }
        #expect(count == 2)
    }
}
