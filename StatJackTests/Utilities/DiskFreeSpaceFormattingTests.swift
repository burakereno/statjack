import Testing
@testable import StatJack

struct DiskFreeSpaceFormattingTests {
    @Test(arguments: [
        (UInt64(0), "0.0 GB"),
        (536_870_912, "0.5 GB"),
        (137_438_953_472, "128.0 GB"),
        (4_398_046_511_104, "4096.0 GB")
    ])
    func availableSpaceStaysInGigabytes(_ testCase: (UInt64, String)) {
        #expect(Formatters.formatDiskFreeSpace(testCase.0) == testCase.1)
    }

    @Test(arguments: [
        (UInt64(0), "0"),
        (1_073_741_823, "0"),
        (1_073_741_824, "1"),
        (79_564_269_158, "74"),
        (4_398_046_511_104, "4096")
    ])
    func menuBarShowsOnlyWholeGigabytes(_ testCase: (UInt64, String)) {
        #expect(Formatters.menuBarDiskFreeSpace(testCase.0) == testCase.1)
    }
}
