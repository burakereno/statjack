import SwiftUI

/// Memory usage view — overall stats and the active/wired/compressed split
struct MemoryView: View {
    let monitor: SystemMonitor

    private var mem: MemoryMonitor { monitor.memoryMonitor }
    private var usage: MemoryUsage { mem.memoryUsage }

    var body: some View {
        MetricCardView(title: "Memory", systemImage: AppIcons.ram) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Formatters.formatBytesCompact(usage.used))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.usageColor(for: usage.usedPercentage))
                        .contentTransition(.numericText())
                    Text("/ \(Formatters.formatBytesCompact(usage.total))")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                UsageBarView(percentage: usage.usedPercentage, height: 6, showLabel: true)

                HStack(spacing: 0) {
                    memoryLabel("Active", value: Formatters.formatBytesCompact(usage.active), color: .blue)
                    Spacer()
                    memoryLabel("Wired", value: Formatters.formatBytesCompact(usage.wired), color: .orange)
                    Spacer()
                    memoryLabel("Compressed", value: Formatters.formatBytesCompact(usage.compressed), color: .purple)
                }
            }
        }
    }

    private func memoryLabel(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Circle()
                    .fill(color.opacity(0.7))
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
