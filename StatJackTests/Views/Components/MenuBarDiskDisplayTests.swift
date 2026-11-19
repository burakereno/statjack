import Testing
@testable import StatJack

@MainActor
struct MenuBarDiskDisplayTests {
    @Test(arguments: [
        (false, false, Optional<String>.none),
        (true, false, "71%"),
        (false, true, "74"),
        (true, true, "71% 74")
    ])
    func diskDisplaysCanBeEnabledIndependently(_ testCase: (Bool, Bool, String?)) {
        let (showUsage, showFree, expected) = testCase
        let result = segments(showUsage: showUsage, showFree: showFree)

        #expect(result.count == (expected == nil ? 0 : 1))
        #expect(result.first?.text == expected)
        #expect(MenuBarDisplay.showIconOnly(
            iconOnly: false,
            showCPU: false,
            showRAM: false,
            showDisk: showUsage,
            showDiskFree: showFree,
            showNetwork: false,
            showGPU: false,
            showTemperature: false
        ) == (expected == nil))
    }

    @Test
    func iconOnlyHidesBothDiskValues() {
        #expect(segments(showUsage: true, showFree: true, iconOnly: true).isEmpty)
    }

    private func segments(showUsage: Bool, showFree: Bool, iconOnly: Bool = false) -> [MenuBarMetricSegment] {
        MenuBarDisplay.metricSegments(
            iconOnly: iconOnly,
            showCPU: false,
            showRAM: false,
            showDisk: showUsage,
            showDiskFree: showFree,
            showNetwork: false,
            showGPU: false,
            showTemperature: false,
            cpu: "",
            ram: "",
            disk: "71%",
            diskFree: Formatters.menuBarDiskFreeSpace(74_100_000_000),
            net: "",
            gpu: "",
            temp: ""
        )
    }
}
