import Testing
@testable import StatJack

@MainActor
struct MenuBarStatusImageRendererTests {
    @Test
    func replacingSameWidthValueDoesNotKeepOldGlyphPixels() throws {
        let renderer = MenuBarStatusImageRenderer()
        _ = renderer.image(for: segments(cpu: "39%"))

        let reusedImage = renderer.image(for: segments(cpu: "31%"))
        let freshImage = MenuBarStatusImageRenderer().image(for: segments(cpu: "31%"))

        #expect(try #require(reusedImage.tiffRepresentation) == freshImage.tiffRepresentation)
    }

    private func segments(cpu: String) -> [MenuBarMetricSegment] {
        MenuBarDisplay.metricSegments(
            iconOnly: false,
            showCPU: true,
            showRAM: false,
            showDisk: false,
            showNetwork: false,
            showGPU: false,
            showTemperature: false,
            cpu: cpu,
            ram: "",
            disk: "",
            net: "",
            gpu: "",
            temp: ""
        )
    }
}
