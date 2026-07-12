import Testing
@testable import StatJack

@MainActor
struct FormattingAndVersionTests {
    @Test
    func compactSpeedKeepsMenuBarValuesBounded() {
        #expect(Formatters.formatSpeedCompact(0) == "0K")
        #expect(Formatters.formatSpeedCompact(1_024) == "1K")
        #expect(Formatters.formatSpeedCompact(100 * 1_024) == "99K")
        #expect(Formatters.formatSpeedCompact(2 * 1_024 * 1_024) == "2M")
    }

    @Test
    func versionComparisonHandlesDifferentComponentCounts() {
        #expect(UpdateChecker.compare("1.0.30", isNewerThan: "1.0.29"))
        #expect(UpdateChecker.compare("1.1", isNewerThan: "1.0.99"))
        #expect(!UpdateChecker.compare("1.0.29", isNewerThan: "1.0.29"))
        #expect(!UpdateChecker.compare("1.0", isNewerThan: "1.0.1"))
    }
}
