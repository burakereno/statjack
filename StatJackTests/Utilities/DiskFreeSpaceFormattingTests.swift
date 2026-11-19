import Testing
@testable import StatJack

struct DiskFreeSpaceFormattingTests {
    @Test(arguments: [
        (UInt64(0), "0.0 GB"),
        (500_000_000, "0.5 GB"),
        (128_000_000_000, "128.0 GB"),
        (4_096_000_000_000, "4096.0 GB")
    ])
    func availableSpaceStaysInGigabytes(_ testCase: (UInt64, String)) {
        #expect(Formatters.formatDiskFreeSpace(testCase.0) == testCase.1)
    }

    @Test(arguments: [
        (UInt64(0), "0"),
        (999_999_999, "0"),
        (1_000_000_000, "1"),
        (74_100_000_000, "74"),
        (4_096_000_000_000, "4096")
    ])
    func menuBarShowsOnlyWholeGigabytes(_ testCase: (UInt64, String)) {
        #expect(Formatters.menuBarDiskFreeSpace(testCase.0) == testCase.1)
    }
}
