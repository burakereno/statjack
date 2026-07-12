import Testing
@testable import StatJack

struct MemoryUsageTests {
    @Test
    func usedMemoryMatchesAppWiredAndCompressedCategories() {
        let usage = MemoryUsage.calculated(
            total: 1_000,
            pageSize: 1,
            internalPages: 500,
            purgeablePages: 100,
            wiredPages: 200,
            compressedPages: 100,
            freePages: 200
        )

        #expect(usage.app == 400)
        #expect(usage.wired == 200)
        #expect(usage.compressed == 100)
        #expect(usage.used == 700)
        #expect(usage.usedPercentage == 70)
    }

    @Test
    func purgeablePagesCannotProduceNegativeAppMemory() {
        let usage = MemoryUsage.calculated(
            total: 1_000,
            pageSize: 1,
            internalPages: 100,
            purgeablePages: 200,
            wiredPages: 50,
            compressedPages: 25,
            freePages: 825
        )

        #expect(usage.app == 0)
        #expect(usage.used == 75)
    }

    @Test
    func usedMemoryIsClampedToPhysicalMemory() {
        let usage = MemoryUsage.calculated(
            total: 1_000,
            pageSize: 1,
            internalPages: 900,
            purgeablePages: 0,
            wiredPages: 400,
            compressedPages: 300,
            freePages: 0
        )

        #expect(usage.used == 1_000)
        #expect(usage.usedPercentage == 100)
    }
}
