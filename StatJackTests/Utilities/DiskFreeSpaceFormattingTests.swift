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
}
