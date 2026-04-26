import SwiftUI

/// Memory usage view — overall stats and the active/wired/compressed split
struct MemoryView: View {
    let monitor: SystemMonitor

    private var mem: MemoryMonitor { monitor.memoryMonitor }
    private var usage: MemoryUsage { mem.memoryUsage }

    var body: some View {
        MetricCardView(title: "Memory", systemImage: AppIcons.ram) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Formatters.formatBytesCompact(usage.used))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.usageColor(for: usage.usedPercentage))
                        .contentTransition(.numericText())
                    Text("/ \(Formatters.formatBytesCompact(usage.total))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                UsageBarView(percentage: usage.usedPercentage, height: 7)

                SparklineView(
                    values: monitor.ramHistory,
                    color: AppColors.usageColor(for: usage.usedPercentage),
                    maxValue: 100
                )

                HStack(spacing: 12) {
                    memoryLegend("ACT", value: Formatters.formatBytesCompact(usage.active), color: .blue)
                    memoryLegend("WIR", value: Formatters.formatBytesCompact(usage.wired), color: .orange)
                    memoryLegend("COMP", value: Formatters.formatBytesCompact(usage.compressed), color: .purple)
                    Spacer()
                }
            }
        }
    }

    private func memoryLegend(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
