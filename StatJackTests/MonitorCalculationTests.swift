import Darwin
import Testing
@testable import StatJack

@MainActor
struct MonitorCalculationTests {
    @Test
    func cpuUsageUsesCounterDeltas() {
        let monitor = CPUMonitor()
        monitor.apply(CPUSample(cores: [.init(user: 1_000, system: 500, idle: 8_000, nice: 100)]))
        monitor.apply(CPUSample(cores: [.init(user: 1_100, system: 550, idle: 8_800, nice: 150)]))

        #expect(monitor.userUsage == 15)
        #expect(monitor.systemUsage == 5)
        #expect(monitor.totalUsage == 20)
    }

    @Test
    func cpuTicksCanCrossTheSignBitAndWrap() {
        let monitor = CPUMonitor()
        monitor.apply(.init(cores: [.init(user: .max - 3, system: 2_147_483_646, idle: 12, nice: 0)]))
        monitor.apply(.init(cores: [.init(user: 0, system: 2_147_483_650, idle: 20, nice: 0)]))
        #expect(monitor.totalUsage == 50)
    }

    @Test
    func networkUsageUsesElapsedTimeAndSessionBaseline() {
        let monitor = NetworkMonitor()
        monitor.apply(NetworkSample(interfaces: ["en0": .init(bytesIn: 1_000, bytesOut: 500)], timestamp: 10))
        monitor.apply(NetworkSample(interfaces: ["en0": .init(bytesIn: 1_400, bytesOut: 700)], timestamp: 12))

        #expect(monitor.networkUsage.downloadSpeed == 200)
        #expect(monitor.networkUsage.uploadSpeed == 100)
        #expect(monitor.networkUsage.totalDownloaded == 400)
        #expect(monitor.networkUsage.totalUploaded == 200)
    }

    @Test
    func changingInterfacesPreservesTrafficAboveFourGiB() {
        let monitor = NetworkMonitor()
        monitor.apply(.init(interfaces: ["en0": .init(bytesIn: 4_294_967_290, bytesOut: 10)], timestamp: 10))
        monitor.apply(.init(interfaces: ["en0": .init(bytesIn: 4_294_967_310, bytesOut: 20),
                                         "en1": .init(bytesIn: 80_000, bytesOut: 1_000)], timestamp: 12))
        #expect(monitor.networkUsage.downloadSpeed == 10)
        monitor.apply(.init(interfaces: ["en1": .init(bytesIn: 80_030, bytesOut: 2)], timestamp: 14))
        #expect(monitor.networkUsage.totalDownloaded == 50)
        #expect(monitor.networkUsage.totalUploaded == 10)
        #expect(monitor.networkUsage.downloadSpeed == 15)
    }

    @Test
    func liveCountersCanBeReadWithoutRetainingHostRights() throws {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        func refs() throws -> mach_port_urefs_t {
            var count: mach_port_urefs_t = 0
            try #require(mach_port_get_refs(mach_task_self_, host, mach_port_right_t(MACH_PORT_RIGHT_SEND), &count) == KERN_SUCCESS)
            return count
        }
        let initial = try refs()
        for _ in 0..<8 {
            _ = try #require(CPUMonitor.sample())
            _ = try #require(MemoryMonitor.sample())
        }
        // An unrelated in-flight host query in the test host may hold a temporary right.
        #expect(try refs() <= initial + 2)
        _ = try #require(NetworkMonitor.sample())
    }
}
