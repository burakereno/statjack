import Testing
@testable import StatJack

@MainActor
struct MonitorCalculationTests {
    @Test
    func cpuUsageUsesCounterDeltas() {
        let monitor = CPUMonitor()
        monitor.apply(CPUSample(user: 1_000, system: 500, idle: 8_000, nice: 100))
        monitor.apply(CPUSample(user: 1_100, system: 550, idle: 8_800, nice: 150))

        #expect(monitor.userUsage == 15)
        #expect(monitor.systemUsage == 5)
        #expect(monitor.totalUsage == 20)
    }

    @Test
    func networkUsageUsesElapsedTimeAndSessionBaseline() {
        let monitor = NetworkMonitor()
        monitor.apply(NetworkSample(bytesIn: 1_000, bytesOut: 500, timestamp: 10))
        monitor.apply(NetworkSample(bytesIn: 1_400, bytesOut: 700, timestamp: 12))

        #expect(monitor.networkUsage.downloadSpeed == 200)
        #expect(monitor.networkUsage.uploadSpeed == 100)
        #expect(monitor.networkUsage.totalDownloaded == 400)
        #expect(monitor.networkUsage.totalUploaded == 200)
    }
}
